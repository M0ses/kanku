---
status: published
title: HowTo use 'official' openSUSE Images with kanku
date: 2024-04-25 09:40:24
tags:
  - howto 
  - KankuFile
  - openSUSE
author: M0ses <fschreiner@suse.de>
---

In this blog post we will describe the steps to create a KankuFile using a 'official' openSUSE Image.

**TL;DR**

SEE our [example KankuFile](https://raw.githubusercontent.com/M0ses/kanku/master/KankuFile.examples/KankuFile.openSUSE-Leap-15.5-official)

---

## Choose an image

First we would like to explain what settings are required in a KankuFile for a `kanku up` to succeed.

* Access via serial console
* Configured root login (login_user/login_pass)
* `installation` section in `Kanku::Handler::CreateDomain` (if a interactive bootstrapping is required - e.g. `firstboot`)

One of design principals of kanku is the old UNIX pragma `KISS` - "Keep It Simple, Stupid".
As we don't like wasting time by downloading useless stuff 
which is not used afterwards we have choosen the following image for our example:

[kiwi-templates-Minimal](https://build.opensuse.org/package/show/openSUSE:Leap:15.5:Images/kiwi-templates-Minimal)

which has a download size of ~200MB.

## Scaffolding a KankuFile

We recommend to create a base KankuFile with `kanku init -d my-new-vm`.


## KankuFile in detail


### Global Settings

Lets start with the global settings at the beginning of the file.

    domain_name: my-new-vm
    default_job: kanku-job
    login_user: root
    login_pass: linux

Please be aware that 'official' images do not have set a default password.
We have to set it while the interactive bootstrapping process.
We will catch up later on.

### The job definition

Please remember:

* A `job` definition is a list of `tasks`.
* Each `task` executes a `handler`
  * configured by `use_module`

In the following text we will name the tasks by the handler they use.

#### Kanku::Handler::SetJobContext

You can leave the first task untouched, if it already fits your local setup.
Depending on the configured tasks the `host_interface` 
setting might not be required at all.

    jobs:
     kanku-job: # Just a arbitrary string configured in `default_job:`
      -
        use_module: Kanku::Handler::SetJobContext
        options:
          host_interface: eth0


#### Kanku::Handler::OBSCheck

The next task `Kanku::Handler::OBSCheck` can be deleted or commented out,
because the following features are not required in our use case:

* OBSCheck will search for the latest build result
* OBSCheck will fail if the image is building ATM or the project is in a `dirty` state.
   This means that either other build jobs are running or the image is unpublished.
* OBSCheck is able to download images, not yet published, via the OBS API.


#### Kanku::Handler::ImageDownload

The next task which needs to be changed is the `Kanku::Handler::ImageDownload`.
We did not run `Kanku::Handler::OBSCheck` so no `vm_image_url` is stored in the job context.
We need to specify a static link `url` (no `-Build*.*` number in the image name) manually:

      -
        use_module: Kanku::Handler::ImageDownload
        options:
          url: https://download.opensuse.org/distribution/leap/15.5/appliances/openSUSE-Leap-15.5-Minimal-VM.x86_64-kvm-and-xen.qcow2


#### Kanku::Handler::CreateDomain

Now we come to the most complicated part, the `Kanku::Handler::CreateDomain` task.
In the ['official' kanku images]https://build.opensuse.org/project/show/devel:kanku:images) 
we try to avoid manual interaction while the bootstrapping process.

Not so the 'official' openSUSE images.
This is the reason why we need a `installation` section in the `CreateDomain` task.

Another important detail:

`d:k:i`-Images (d:k:i = devel:kanku:images in OBS) are configured to prefer 
the serial console over the default `tty` in grub2 and `kernelcmdline`.
They don't need a graphical output (VNC or SPICE)/keyboard/mouse in their
libvirt-xml.

The 'official' openSUSE images (and many other images like the OBS appliance)
are configured for "the average Joe". 
Therefor we need to configure a different VM `template`.

We recommend the "with-spice" variant included in the `kanku-common` package.

SEE `/etc/kanku/templates/with-spice.tt2` for details.


      -
        use_module: Kanku::Handler::CreateDomain
        options:
          memory: 2G
          vcpu: 1
          use_9p: 1
          template: with-spice # required for proper serial console connection
          installation:
            -
              expect: Welcome
              send_enter: 1
            -
              expect: Select keyboard layout
              send_enter: 1
            -
              expect: LICENSE AGREEMENT
              send_enter: 1
            -
              expect: Select time zone
              send_enter: 1
            -
              expect: Enter root password
              send: linux
              send_enter: 1
            -
              expect: Confirm root password
              send: linux
              send_enter: 1


In the first four steps we just accecpt the default values by "pressing" `[ENTER]`.

The last two steps are more interesting. 

We `send` our new root password.

The password needs to be the same as the `login_pass` we defined as global option at the beginning of the KankuFile.


## Done!?

Thats it. Now we are done ... or ... Wait!

We would recommend to add the following additional tasks:

* `Kanku::Handler::PrepareSSH`
  * deploy openssh-server in the VM
  * your public keys in /root/.ssh/authorized_keys
* `Kanku::Handler::ExecuteCommandViaSSH`
  * test the ssh connection as root to your new VM

**Example:**

    -
        use_module: Kanku::Handler::PrepareSSH
    -
        use_module: Kanku::Handler::ExecuteCommandViaSSH
        options:
          commands:
            - echo "Just checking ssh connnection and key deployment"



We also strongly recommend to enhance your `Kanku::Handler::CreateDomain` task to use pwrand.
This will set a randomized password for the configured list of users 
and encrypt them for a list of configured email addresses using gpg.

SEE `perldoc Kanku::Handler::CreateDomain` and search for pwrand for more information.

Have a lot of fun! (with kanku)

M0ses
