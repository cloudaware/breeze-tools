breeze-agent 
============

* Clone the breeze-tools repo to your server:
```
git clone https://github.com/cloudaware/breeze-tools.git
```
* Put your breeze agent installation files to the `breeze-tools/chef-cookbooks/breeze-agent/files` directory. Note that your files should be called 'breeze-agent-linux.tgz' and 'breeze-agent-windows.exe'.

* Copy breeze-agent cookbook to your cookbook directory and upload it to the server:
```
cp -r breeze-tools/chef-cookbooks/breeze-agent ~/cookbooks/
knife cookbook upload breeze-agent
```

* Create the breeze-agent role:
```
export EDITOR=vim #any other editor can be selected, like nano for instance
knife role create breeze-agent
```
Once in the editor, replace everything with the next content and save:
```
{
  "name": "breeze-agent",
  "description": "",
  "json_class": "Chef::Role",
  "default_attributes": {},
  "override_attributes": {},
  "chef_type": "role",
  "run_list": [ "recipe[breeze-agent]" ],
  "env_run_lists": {}
}
```
* Add the role to the nodes that you need or to all nodes using your web interface or using the next command:
```
knife node run_list add $NODE_NAME 'role[breeze-agent]' #Where $NODE_NAME is the name of the actual node
```
To add the role to all of the nodes you can run:
```
for node in `knife node list`;do knife node run_list add $node 'role[breeze-agent]';done;
```
Next chef-client will have to apply the changes on the nodes, this will just take some time.
