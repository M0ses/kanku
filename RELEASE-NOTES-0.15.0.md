# RELEASE 0.15.0

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



