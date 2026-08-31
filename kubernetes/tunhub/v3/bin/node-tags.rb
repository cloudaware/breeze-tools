#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes the EC2 tags of the node the pod runs on to /breeze-data/node-tags.json, where the agent
# looks for them to resolve the EKS cluster name (+NODE_TAGS_FILE+ in +facts.d/k8s.rb+ of the agent
# gem).
#
# Replaces the Python init container of the legacy manifests. It runs with the Ruby that ships in
# the image, so the pod needs neither a second image nor a package installation at startup, which
# also makes it work in a cluster without egress to a package index.
#
# The tags are read from the first source that answers:
#
# 1. the instance metadata service, for instances that expose their tags (+InstanceMetadataTags+
#    enabled); no credentials and no IAM permission are involved
# 2. the EC2 API, +ec2:DescribeTags+ signed with SigV4, using the first credentials found in the
#    environment, the container credentials endpoint (EKS Pod Identity), the web identity token
#    (IRSA) or the instance role
#
# Environment:
#
#   BREEZE_K8S_NODE_TAGS_FILE   output file, defaults to /breeze-data/node-tags.json
#   BREEZE_K8S_IMDS_ENDPOINT    metadata service, defaults to http://169.254.169.254
#   BREEZE_K8S_EC2_ENDPOINT     EC2 API, defaults to https://ec2.<region>.amazonaws.com

require 'json'
require 'net/http'
require 'openssl'
require 'time'
require 'uri'

module Breeze
  # Collects the EC2 tags of the node
  module NodeTags
    # The tags could not be collected
    class Error < RuntimeError; end

    # The tags were collected, but none of them names the cluster
    class MissingClusterTag < Error; end

    # Credentials for the SigV4 signature, the session token is optional
    Credentials = Struct.new(:access_key_id, :secret_access_key, :session_token)

    # Lifetime of the metadata token, seconds
    IMDS_TOKEN_TTL = '60'

    # Connect and read timeout for every request, seconds
    HTTP_TIMEOUT = 5

    # Version of the EC2 API to call
    EC2_API_VERSION = '2016-11-15'

    # Version of the STS API to call
    STS_API_VERSION = '2011-06-15'

    # Characters that RFC 3986 leaves unreserved, everything else is percent encoded
    UNRESERVED = /[^A-Za-z0-9\-._~]/.freeze

    class << self
      # Writes the node tags to the output file
      # @return [void]
      # @raise [Error] when the tags cannot be collected or do not name a cluster
      def run
        token = imds_token

        tags = tags_from_metadata(token)
        if tags.nil?
          tags = tags_from_ec2_api(token)
          source = 'the EC2 API'
        else
          source = 'the instance metadata'
        end

        # written before the cluster tag is checked, so that the collected tags can be inspected
        # in the pod when the check fails
        write(output_file, tags)
        puts "node tags: #{tags.length} tag(s) from #{source} written to #{output_file}"

        return if cluster_tag?(tags)

        raise MissingClusterTag, 'none of the node tags names the cluster, expected a ' \
                                 'kubernetes.io/cluster/<name> tag with the value owned, or an ' \
                                 'eks:cluster_name tag'
      end

      # Whether the tags name the cluster the node belongs to. Mirrors the rule the agent applies in
      # +eks_cluster_name_from_node_tags+, so that a node whose tags would leave the agent with an
      # instance identity instead of a cluster identity is caught here rather than misreported.
      # @param tags [Array<Hash>] collected tags
      # @return [Boolean] whether a cluster tag is present
      def cluster_tag?(tags)
        tags.any? do |tag|
          tag.any? do |key, value|
            (key.match?(%r{kubernetes\.io/cluster/}) && value == 'owned') || key.match?(/eks:cluster_name/)
          end
        end
      end

      # @return [String] path of the file the agent reads the tags from
      def output_file
        ENV.fetch('BREEZE_K8S_NODE_TAGS_FILE', File.join('', 'breeze-data', 'node-tags.json'))
      end

      # Writes the tags through a temporary file, so that the agent never reads a partial file
      # @param file [String] output file
      # @param tags [Array<Hash>] tags as single pair hashes, the format the agent parses
      # @return [void]
      def write(file, tags)
        temporary_file = "#{file}.new"
        File.write(temporary_file, JSON.generate(tags))
        File.rename(temporary_file, file)
      end

      # @return [String] metadata service base URL
      def imds_endpoint
        ENV.fetch('BREEZE_K8S_IMDS_ENDPOINT', 'http://169.254.169.254')
      end

      # Requests a metadata token, IMDSv2
      # @return [String] token
      def imds_token
        uri = URI.join(imds_endpoint, '/latest/api/token')
        request = Net::HTTP::Put.new(uri)
        request['X-aws-ec2-metadata-token-ttl-seconds'] = IMDS_TOKEN_TTL
        http_request(request, uri)
      end

      # Reads a path from the metadata service
      # @param path [String] metadata path
      # @param token [String] metadata token
      # @return [String] response body
      def imds_get(path, token)
        uri = URI.join(imds_endpoint, path)
        request = Net::HTTP::Get.new(uri)
        request['X-aws-ec2-metadata-token'] = token
        http_request(request, uri)
      end

      # Reads the tags from the metadata service, which serves them only when the instance was
      # launched with the tags exposed
      # @param token [String] metadata token
      # @return [Array<Hash>, nil] tags, or +nil+ when the metadata service does not serve them
      def tags_from_metadata(token)
        keys = imds_get('/latest/meta-data/tags/instance', token).split("\n").reject(&:empty?)
        return nil if keys.empty?

        keys.map do |key|
          { key => imds_get("/latest/meta-data/tags/instance/#{percent_encode(key)}", token) }
        end
      rescue Error
        nil
      end

      # Reads the tags of this instance with a signed ec2:DescribeTags call
      # @param token [String] metadata token
      # @return [Array<Hash>] tags
      def tags_from_ec2_api(token)
        region = imds_get('/latest/meta-data/placement/region', token)
        instance_id = imds_get('/latest/meta-data/instance-id', token)

        query = canonical_query(
          'Action' => 'DescribeTags',
          'Filter.1.Name' => 'resource-id',
          'Filter.1.Value.1' => instance_id,
          'Version' => EC2_API_VERSION
        )

        uri = URI("#{ENV.fetch('BREEZE_K8S_EC2_ENDPOINT', "https://ec2.#{region}.amazonaws.com")}/?#{query}")
        request = Net::HTTP::Get.new(uri)
        signature_headers(
          method: 'GET', uri: uri, query: query, region: region,
          service: 'ec2', credentials: credentials(token)
        ).each_pair { |name, value| request[name] = value }

        parse_tag_set(http_request(request, uri))
      end

      # Extracts the tags from an EC2 DescribeTags response
      # @param body [String] response body
      # @return [Array<Hash>] tags as single pair hashes
      def parse_tag_set(body)
        body.scan(%r{<item>(.*?)</item>}m).flatten.map do |item|
          key = item[%r{<key>(.*?)</key>}m, 1]
          next nil if key.nil?

          { unescape_xml(key) => unescape_xml(item[%r{<value>(.*?)</value>}m, 1].to_s) }
        end.compact
      end

      # Returns the first credentials the pod has, in the order the AWS SDKs use
      # @param token [String] metadata token
      # @return [Credentials] credentials
      def credentials(token)
        credentials_from_environment ||
          credentials_from_container ||
          credentials_from_web_identity ||
          credentials_from_instance_role(token) ||
          raise(Error, 'no AWS credentials found')
      end

      # @return [Credentials, nil] credentials from the environment
      def credentials_from_environment
        access_key_id = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
        secret_access_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
        return nil if access_key_id.nil? || secret_access_key.nil?

        Credentials.new(access_key_id, secret_access_key, ENV.fetch('AWS_SESSION_TOKEN', nil))
      end

      # Credentials from the container credentials endpoint, used by EKS Pod Identity
      # @return [Credentials, nil] credentials
      def credentials_from_container
        full_uri = ENV.fetch('AWS_CONTAINER_CREDENTIALS_FULL_URI', nil)
        relative_uri = ENV.fetch('AWS_CONTAINER_CREDENTIALS_RELATIVE_URI', nil)
        return nil if full_uri.nil? && relative_uri.nil?

        uri = URI(full_uri || "http://169.254.170.2#{relative_uri}")
        request = Net::HTTP::Get.new(uri)

        token_file = ENV.fetch('AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE', nil)
        authorization = token_file.nil? ? ENV.fetch('AWS_CONTAINER_AUTHORIZATION_TOKEN', nil) : File.read(token_file).strip
        request['Authorization'] = authorization unless authorization.nil?

        document = JSON.parse(http_request(request, uri))
        Credentials.new(document['AccessKeyId'], document['SecretAccessKey'], document['Token'])
      end

      # Credentials for a service account annotated with a role, IRSA. The web identity token is
      # exchanged for temporary credentials, a call that carries no signature of its own.
      # @return [Credentials, nil] credentials
      def credentials_from_web_identity
        token_file = ENV.fetch('AWS_WEB_IDENTITY_TOKEN_FILE', nil)
        role_arn = ENV.fetch('AWS_ROLE_ARN', nil)
        return nil if token_file.nil? || role_arn.nil? || !File.readable?(token_file)

        region = ENV.fetch('AWS_REGION', nil) || ENV.fetch('AWS_DEFAULT_REGION', nil) || 'us-east-1'
        uri = URI(ENV.fetch('BREEZE_K8S_STS_ENDPOINT', "https://sts.#{region}.amazonaws.com/"))
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          'Action' => 'AssumeRoleWithWebIdentity',
          'RoleArn' => role_arn,
          'RoleSessionName' => ENV.fetch('AWS_ROLE_SESSION_NAME', "breeze-#{Process.pid}"),
          'Version' => STS_API_VERSION,
          'WebIdentityToken' => File.read(token_file).strip
        )

        document = http_request(request, uri)
        Credentials.new(
          document[%r{<AccessKeyId>(.*?)</AccessKeyId>}m, 1],
          document[%r{<SecretAccessKey>(.*?)</SecretAccessKey>}m, 1],
          document[%r{<SessionToken>(.*?)</SessionToken>}m, 1]
        )
      end

      # Credentials of the role attached to the instance
      # @param token [String] metadata token
      # @return [Credentials, nil] credentials
      def credentials_from_instance_role(token)
        path = '/latest/meta-data/iam/security-credentials/'
        role = imds_get(path, token).split("\n").first
        return nil if role.nil? || role.empty?

        document = JSON.parse(imds_get("#{path}#{percent_encode(role)}", token))
        Credentials.new(document['AccessKeyId'], document['SecretAccessKey'], document['Token'])
      rescue Error, JSON::ParserError
        nil
      end

      # Builds the headers that authenticate a request, AWS Signature Version 4
      # @param method [String] HTTP method
      # @param uri [URI] request URI
      # @param query [String] canonical query string
      # @param region [String] AWS region
      # @param service [String] AWS service name
      # @param credentials [Credentials] credentials to sign with
      # @param payload [String] request body
      # @param now [Time] signature timestamp
      # @return [Hash] headers, including the authorization header
      def signature_headers(method:, uri:, query:, region:, service:, credentials:, payload: '', now: Time.now.utc)
        timestamp = now.strftime('%Y%m%dT%H%M%SZ')
        date = now.strftime('%Y%m%d')
        scope = [date, region, service, 'aws4_request'].join('/')

        headers = { 'host' => uri.host, 'x-amz-date' => timestamp }
        headers['x-amz-security-token'] = credentials.session_token unless credentials.session_token.nil?

        signed_headers = headers.keys.sort.join(';')
        canonical_headers = headers.sort.map { |name, value| "#{name}:#{value}\n" }.join
        canonical_request = [
          method, uri.path, query, canonical_headers, signed_headers, OpenSSL::Digest::SHA256.hexdigest(payload)
        ].join("\n")

        string_to_sign = [
          'AWS4-HMAC-SHA256', timestamp, scope, OpenSSL::Digest::SHA256.hexdigest(canonical_request)
        ].join("\n")

        signing_key = ["AWS4#{credentials.secret_access_key}", date, region, service, 'aws4_request']
                      .inject { |key, data| OpenSSL::HMAC.digest('sha256', key, data) }
        signature = OpenSSL::HMAC.hexdigest('sha256', signing_key, string_to_sign)

        headers.merge(
          'authorization' => "AWS4-HMAC-SHA256 Credential=#{credentials.access_key_id}/#{scope}, " \
                             "SignedHeaders=#{signed_headers}, Signature=#{signature}"
        )
      end

      # Sorts and encodes the query parameters the way the signature expects
      # @param parameters [Hash] query parameters
      # @return [String] canonical query string
      def canonical_query(parameters)
        parameters.sort.map { |name, value| "#{percent_encode(name)}=#{percent_encode(value)}" }.join('&')
      end

      # Percent encodes everything RFC 3986 does not leave unreserved
      # @param string [String] value to encode
      # @return [String] encoded value
      def percent_encode(string)
        string.to_s.gsub(UNRESERVED) { |char| char.bytes.map { |byte| format('%%%02X', byte) }.join }
      end

      # Replaces the entities an AWS XML response uses
      # @param string [String] escaped value
      # @return [String] value
      def unescape_xml(string)
        string.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&apos;', "'").gsub('&amp;', '&')
      end

      # Performs a request and returns its body
      # @param request [Net::HTTPRequest] request to perform
      # @param uri [URI] request URI
      # @return [String] response body
      # @raise [Error] on a connection failure or a non 2xx response
      def http_request(request, uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = HTTP_TIMEOUT
        http.read_timeout = HTTP_TIMEOUT

        response = http.request(request)
        unless response.is_a?(Net::HTTPSuccess)
          raise Error, "#{request.method} #{uri} => #{response.code} #{response.message}"
        end

        response.body.to_s.strip
      rescue Error
        raise
      rescue StandardError => e
        raise Error, "#{request.method} #{uri} => #{e.class}: #{e.message}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # keep the progress and the failure in the order they happen, stderr is not buffered
  $stdout.sync = true

  begin
    Breeze::NodeTags.run
  rescue Breeze::NodeTags::MissingClusterTag => e
    # a status of its own, so that the caller can tell tags that were collected but do not name
    # the cluster from tags that could not be collected at all
    warn "node tags: #{e.message}"
    exit 2
  rescue Breeze::NodeTags::Error => e
    warn "node tags: #{e.message}"
    exit 1
  end
end
