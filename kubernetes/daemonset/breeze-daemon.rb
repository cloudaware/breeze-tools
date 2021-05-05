#!/opt/breeze-agent/ruby/bin/ruby

require 'optparse'

module Breeze
  # class for Breeze daemon
  class Daemon
    def self.run!(options = {})
      Breeze::Daemon.new(options).run!
    end

    attr_reader :last_agent_time
    attr_reader :options
    attr_reader :quit

    def initialize(options = {})
      @options = options
      @options[:interval] ||= 15 * 60
    end

    def run!
      trap_signals
      until quit
        run_agent if should_run_now?
        sleep 2
      end
    end

    private

    def trap_signals
      %w[INT QUIT TERM].each do |signal|
        Signal.trap(signal) do
          puts "Catch signal SIG#{signal}."
          @quit = signal
        end
      end
    end

    def run_agent
      @last_agent_time = Time.now
      pid = spawn(@options[:command])
      Process.detach(pid)
    end

    def should_run_now?
      (Time.now.to_i - last_agent_time.to_i) >= options[:interval]
    end
  end
end

options = {
  interval: 15 * 60
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"
  opts.on('-c', '--command VALUE', String, 'Run command.') do |o|
    options[:command] = o
  end
  opts.on('-i', '--interval VALUE', Integer,
          "Set interval in seconds. Default: #{options[:interval]}.") do |o|
    options[:interval] = o
  end
  opts.on_tail('-h', '--help', 'Show this message.') do
    puts opts
    exit
  end
end.parse!

if options[:command].to_s.empty?
  puts 'Command required.'
  exit 1
end

Breeze::Daemon.run!(options)
