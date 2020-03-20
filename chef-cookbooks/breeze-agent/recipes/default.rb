# Cookbook:: breeze-agent
# Recipe:: default

if node['kernel']['name'] == 'Linux'
  cookbook_file '/tmp/breeze-agent-linux.tgz' do
    source 'breeze-agent-linux.tgz'
    action :create_if_missing
  end

  execute 'extract_breeze-agent' do
    command 'tar xzf /tmp/breeze-agent-linux.tgz'
    cwd '/tmp'
    not_if { File.exists?("/tmp/breeze-agent/install.sh") }
  end

  execute 'install-breeze-agent-linux' do
    user 'root'
    cwd '/tmp/breeze-agent'
    command './install.sh'
    creates '/opt/breeze-agent/app.sh'
  end
else
  cookbook_file 'C:/breeze-agent-windows.exe' do
    source 'breeze-agent-windows.exe'
    action :create_if_missing
  end

  execute 'install-breeze-agent-windows' do
    command 'C:/breeze-agent-windows.exe'
    cwd 'C:/'
    creates 'C:/Program Files/Breeze/app.bat'
  end
end
