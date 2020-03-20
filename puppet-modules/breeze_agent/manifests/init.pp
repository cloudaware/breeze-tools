# Install and configure the breeze_agent module
class breeze_agent (
  $breeze_package_linux   = $::breeze_package_linux,
  $breeze_package_windows = $::breeze_package_windows,
) {

  if $::kernel == 'Linux' {

    file { 'breeze-agent':
      ensure => present,
      path   => '/tmp/breeze-agent.linux.tgz',
      source => "puppet:///modules/breeze_agent/${breeze_package_linux}",
    }

    exec { 'unpack-breeze':
      path    => ['/usr/bin', '/usr/sbin', '/bin', '/usr/local/sbin', '/sbin'],
      command => 'tar zxf /tmp/breeze-agent.linux.tgz -C /opt',
      creates => '/opt/breeze-agent/app.rb',
      require => File['breeze-agent'],
    }

    file { 'cron-file':
      ensure  => present,
      path    => '/etc/cron.d/breeze-agent',
      require => Exec['unpack-breeze'],
      content => "*/15 * * * * root /opt/breeze-agent/app.sh >> /var/log/breeze-agent.log 2>&1\n", # lint:ignore:80chars

    }

  } else {

    file { 'breeze-agent':
      ensure => present,
      path   => 'C:\\breeze-agent.exe',
      source => "puppet:///modules/breeze_agent/${breeze_package_windows}",
    }

    exec { 'install-breeze':
      command => 'C:\\breeze-agent.exe',
      creates => 'C:\\Program Files\\Breeze\\app.bat',
    }

  }

}
