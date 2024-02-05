# [0.16.1] - 2024-02-05

## BUGFIXES

* [dist] multiple improvements in packaging for rpm based distros


# [0.16.0] - 2023-11-30

## FEATURES

* [feature] Implemented HTTP Signature Authentication
* [feature] Defaults handling migrated to K::Config::Defaults


## BUGFIXES

* [cli] cleanup unused packages in urlwrapper


# [0.15.0] - 2023-11-30

## FEATURES

* [cli] configurable apiurl for init and lsi
* initial version of worker setup
* [core] waitpid when stopping dispatcher
* [web] improved login page
* [web] show error message if user is not logged in
* [handler] CreateDomain: added vcpu/memory to gui_config
* [handler] GIT: new option 'recursive' for recursive clones


## BUGFIXES

* [handler] OBSServerFrontendTests: fix cleanup temp and logfiles if succeeded
* [handler] ImageDownload: always set vm_image_file if found vm_image_url
* [handler] OBSServerFrontendTests: fix stuck test runs
* [core] fix for rabbitmq reconnect
* [worker] fixed routing key used for sending job_aborted
* [handler] GIT: fixed mirror mode
* [handler] SetupNetwork: fixed pod
* [core] set job_group start_time before dispatching
* [core] fixing rabbit retry time
* [util] VM: changed default accessmode_9p to 'squash'
* [handler] OBSServerFrontendTests: changed to user kanku and use local path
* [handler] OBSServerFrontendTests: split commands
* [dist] set timeout for kanku-worker.service to 90sec
* [dispatcher] kill dispatcher process running dead jobs
* [dispatcher] clean up dead job groups on dispatcher startup/shutdown
* [worker] send aborted_job to correct job queue
* [web] return error if data for job_group rest call is HASH
* [worker] do not return before destroying queue
* [examples] updated KankuFile.openQA
* [handler] SetupNetwork: added timeout


# [0.14.0] - 2023-01-10

## FEATURES

* [web] first working version of job_group triggers via token auth
* [web] creation time in job info
* [core] configurable git parameters for job groups
* [dispatcher] locking for job groups
* [cli] rtrigger: added trigger for job_group's
* [dist] added GitLab::WebHook example to dancer config template
* [core] replaced Net::SSH2 with Libssh::Session
* [examples] install job group examples in sostw job in KankuFile
* [handler] PreparSSH: global config for 'public_key_files' in kanku-config.yml
* [core] dispatcher cleanup jobs waiting for recursivly


## BUGFIXES

* [core] catch rabbitmq connection error and reconnect
* [dispatcher] fix data caching issues with job groups
* [core] fix 'uninitialized value' issues
* [web] skipped jobs showed as warnings
* [setup] copy certs only if dest does not exists
* [web] automatically enable all jobs in job_group which are not exlicitly disabled
* [core] added timeout_nodata for SSH
* [handler] OBSServerFrontendTests: fix timeout problem
* [handler] CreateDomain: die if no vm_image_file in ctx
* [cli] avoid 'uninitialized' warnings in rjob when no filter is set


# [0.13.0] - 2022-10-10

## FEATURES

* [core] refactored rabbmitmq handling in worker and dispatcher
* [handler] Reboot: new option 'login_timeout' to wait for console
* [handler] SaltSSH: added multiple attributes
* [dist] removed kanku-web.log from default logging conf
* [dist] remove logrotate config - now done with journald
* [cli] ssh: new parameter --x11_forward/-X to enable ssh x11 forwarding


# [0.12.7] - 2022-06-23

## BUGFIXES

* [handler] K:H:GIT - fixed gituser/gitpass handling
* [cli] up: fixed special job `__ALL__`


# [0.12.6] - 2022-06-22

## FEATURES

* [cli] up: new special job `__ALL__` where a sequence of jobs can be defined in an array
* [cli] up: multiple jobs can now be specified as options
* [handler] new Kanku::Handler::CopyProfile


# [0.12.5] - 2022-06-03

## FEATURES

* [cli] up: new alias for ```--skip_check_domain``` -> ```-S```
* [cli] ssh: new option ```--agent_forward | -A```
* [cli] up:  new option ```--skip_check_domain | -S```
* [util] limit `use cache=unsafe` to vmdk images - speed improvement for other images
* [dist] fixed order of iptables rules when using multiple networks (server mode)
* [handler] SetupNetwork: changed get_ipaddress to console


# [0.12.4] - 2022-05-06

## BUGFIXES

* [util] improve vmdk performance (`cache=unsafe` in libvirt disk driver)
* [web] fixed 'To Top'-button


# [0.12.3] - 2022-03-14

## FEATURES

* [cli] check_configs command now also check job_group configs


## BUGFIXES

* [web] fix outdated cached settings in 'Job Groups'
* [core] #boo 1196604 - wrapper scripts for iptables/ss/netstat
* [dist] change default logging to stderr/journald
* [util] VM::Image - use new buffer size while uncompressing
* [urlwrapper] fixed x-scheme-handler_kanku
* [handler] central config for host_interfaces for PortForward
* [web] job groups config changes are now detected in web ui


# [0.12.2] - 2022-02-18

## BUGFIXES

* [web] guest page - filter iptable rules by domain name


# [0.12.1] - 2022-02-16

## FEATURES

* [dist] new systemd service kanku-iptables for master server


# [0.12.0] - 2022-02-09

## FEATURES

* [web]
  * new switch autostart to create persistent VM's
  * added login route (for GET method)
* [cli]
  * new command `kanku snapshot ...`
  * new options for `kanku ssh ...`:
    * `--ipaddress` to specify the ip address of the VM (alias `-i`)
    * `--execute` to execute a single command via ssh (alias `-e`)
  * use ssh_user from KankuFile for ssh command
  * new option: `--log_file/--log_stdout` for VM related commands
  * Suggest running ssh-add on auth fauilure when auth_type is 'agent'


## BUGFIXES

* [web]
  * fix 'show only latest' in job history
* [core]
  * no_wait_for_bootloader for ExecuteCommandsViaConsole to avoid waiting for bootloader
  * Fix ssh key filename: id_ecdsa.pub_sk -> id_ecdsa_sk.pub
  * various cleanups to avoid 'uninitialized value'
* [dist]
  * fix tabs in default config template setup/kanku-config.yml.tt2
  * K:H:PrepareSSH: fix permissions for user kanku
  * K:H:CleanupIPTables: cleanup unused packages
* [util]
  * set default for running_remotely in VM to 0
* [examples] updated configs
  * updated to current opensuse
  * deleted broken examples
  * updated centos to latest version
  * renamed centos -> centos-current


