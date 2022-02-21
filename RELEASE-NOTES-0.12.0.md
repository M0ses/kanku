# Release 0.12.0

## New Featues

* [web]
  * new switch autostart to create persistent VM's
  * added login route (for GET method)
* [cli]
  * new commands "kanku snapshot ..."
  * new options for "kanku ssh ..."
    * --ipaddress to specify the ip address of the VM
    * --execute to execute a single command via ssh
  * use ssh_user from KankuFile for ssh command
  * new options `--log_file/--log_stdout` for VM related commands
  * Suggest running ssh-add on auth fauilure when auth_type is 'agent'


## Bugfixes

* [web]
  * fix 'show only latest' in job history
* [core]
  * no_wait_for_bootloader for ExecuteCommandsViaConsole to avoid waiting for bootloader
  * Fix ssh key filename: id_ecdsa.pub_sk -> id_ecdsa_sk.pub
  * various cleanups to avoid 'uninitialized value'
* [dist]
  * fix tabs in default config template setup/kanku-config.yml.tt2
* [handler]
  * fix permissions for user kanku in PrepareSSH
  * cleanup unused packages in CleanupIPTable
* [util] set default for running_remotely in VM to 0


## Example Configs

* updated to current opensuse
* deleted broken examples
* updated centos to latest version
* renamed centos -> centos-current

