# RELEASE 0.14.0


<h2>Attention:</h2>
<p>An update of the database schema (version 18) is required with the new release.<br>
   <strong>Don't forget to update your database.</strong><br>
</p>
<p>For developer mode use:</p>
<code>kanku db --upgrade</code>
<p>For server mode use:</p>
<code>kanku db --upgrade --server</code>

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



