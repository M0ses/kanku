# Installation

One of the goals of kanku is to make your life easier, and therefor we provide packages for most major distributions.

Please visit [devel:kanku](https://build.opensuse.org/project/show/devel:kanku) to see all currently available packages for the various distributions.

As you might have read already in the [introduction](/) kanku offers two modes and we recommend to choose the appropriate package for your needs.

* kanku-cli (Developer Mode)
* kanku (Server Mode - almost everthing)


## openSUSE


    zypper ar obs://devel:kanku devel:kanku
    zypper ar obs://devel:kanku:perl devel:kanku:perl
    zypper ref -s
    zypper in kanku-cli


## Fedora/RedHat


    curl https://download.opensuse.org/repositories/devel:/kanku/Fedora_Rawhide/devel:kanku.repo > /etc/yum.repos.d/devel:kanku.repo
    curl https://download.opensuse.org/repositories/devel:/kanku:/perl/Fedora_Rawhide/devel:kanku:perl.repo > /etc/yum.repos.d/devel:kanku:perl.repo
    dnf install kanku-cli
    usermod -a -G wheel kanku
    usermod -a -G libvirt kanku


## Ubuntu/Debian


    sudo sh -c 'echo "deb https://download.opensuse.org/repositories/devel:/kanku/xUbuntu_22.04/ ./" > /etc/apt/sources.list.d/kanku.list'
    sudo sh -c 'echo "deb https://download.opensuse.org/repositories/devel:/kanku:/perl:/deb/xUbuntu_22.04/ ./" >> /etc/apt/sources.list.d/kanku.list'
    curl https://download.opensuse.org/repositories/devel:/kanku:/perl:/deb/xUbuntu_22.04/Release.key |sudo apt-key add -
    curl https://download.opensuse.org/repositories/devel:/kanku:/staging/xUbuntu_22.04/Release.key   |sudo apt-key add -
    sudo apt update
    sudo apt install -y kanku-cli


## Setup your environment

    sudo kanku setup devel

    # if you would like to have more control about the modifications on your system
    # please use:
    # sudo kanku setup --devel --interactive

    sudo shutdown -r now


### Prepare a new Project

In Kanku, a "project" is a file, usually called `KankuFile`, which is
associated with a libvirt domain (which means a VM, in libvirt terminology).

The easiest way to manage your projects is to keep them in individual
directories (it is also possible to have a single directory containing
multiple Kankufiles, but this is slightly more complicated):

    # create directory
    mkdir MyProject

    # cd in project's directory
    cd MyProject

The command `kanku init` will create a default `KankuFile` in the current
directory, which should give you a good starting point.

The option `--memory=...` defines the RAM of the virtual guest and is optional.
The default is 2G of RAM. For more options, see `kanku init --help`.

    kanku init --memory=2G --domain_name my-project

(The `--domain_name` option is not required: if not given, kanku will assign
a default domain name. However, this can lead to name collisions later on when
you create a second VM!)


### Create a VM

Now, `kanku init` only creates the `KankuFile` in your project directory. To
create the VM, issue the command:

    kanku up


### Connect to the VM

Per default, if it exists, your ssh key is added to the authorized keys file.

Otherwise you can login as

* User: kanku / Password "kankusho"
* User: root / Pasword "kankudai"

**Please change the passwords at first login**


#### Connect with user kanku

    kanku ssh

#### Connect as user root

    kanku ssh -u root
