---
title: RELEASE 1.0.0
date: 2025-03-18 08:31:33
tags: release
template: blog/release-post.html
data:
  release: 1.0.0
  warnings: |-
            <h2>Attention:</h2>
            <p>See the following table for changed commands</p>
            <code>
             +-------------------+-------------------------------+----------------------------------------------------------------+  
             |  version > 0.17.x |  version < 0.99               |  Comment                                                       | 
             +-------------------+-------------------------------+----------------------------------------------------------------+  
             |  browser          |  NEW                          |  open url for guest vm with xdg-open                           | 
             |  db install       |  db --install                 |                                                                | 
             |  db status        |  db --status                  |                                                                | 
             |  db upgrade       |  db --upgrade                 |                                                                | 
             |  doc              |  NEW                          |  Show documenation for kanku libraries                         | 
             |  hub gpgimport    |  NEW                          |  Import gpg keys of kanku-hub maintainers                      | 
             |  hub sign         |  NEW                          |  Sign Kankufile's in kanku-hub                                 | 
             |  hub test         |  NEW                          |  Test Kankufile's in kanku-hub                                 | 
             |  info             |  NEW                          |  Show info from KankuFile                                      | 
             |  rcomment create  |  rcomment <--create|-c>       |  list job history on your remote kanku instance                | 
             |  rcomment delete  |  rcomment <--delete|-D>       |  list job history on your remote kanku instance                | 
             |  rcomment list    |  rcomment <--list|-l>         |  list job history on your remote kanku instance                | 
             |  rcomment modify  |  rcomment <--modify|-M>       |  list job history on your remote kanku instance                | 
             |  rguest console   |  NEW                          |  open console to guest on kanku worker via ssh                 | 
             |  rguest list      |  rguest   <--list|-l>         |  list guests on your remote kanku instance                     | 
             |  rguest ssh       |  NEW                          |  ssh to kanku guest on your remote kanku instance              | 
             |  rhistory details |  rhistory <--details|-d>      |  list job history on your remote kanku instance                | 
             |  rhistory list    |  rhistory <--list|-l>         |  list job history on your remote kanku instance                | 
             |  rjob config      |  rjob     <--config|-c>       |  show result of tasks from a specified remote job              | 
             |  rjob details     |  rjob     <--details|-d>      |  show result of tasks from a specified remote job              | 
             |  rjob list        |  rjob     <--list|-l>         |  show result of tasks from a specified remote job              | 
             |  rworker list     |                               |  information about worker                                      | 
             |  setup devel      |  setup --devel                |  Setup local environment to work in developer mode.            | 
             |  setup server     |  setup --server               |  Setup local environment to work as server or developer mode.  | 
             |  setup worker     |  NOT IMPLEMENTED              |  Setup local environment as kanku worker                       | 
             |  snapshot create  |  snapshot <--create|-c>       |  Create snapshot of kanku vm                                   | 
             |  snapshot list    |  snapshot <--list|-l>         |  list snapshots of kanku vms                                   | 
             |  snapshot remove  |  snapshot <--remove|-r>       |  manage snapshots for kanku vms                                | 
             |  snapshot revert  |  snapshot <--revert|-R>       |  revert snapshots of kanku vms                                 | 
             |  verify           |                               |  verify gpg signature of KankuFile in your current             | 
             +-------------------+-------------------------------+----------------------------------------------------------------+ 
            </code>
  features:
    - |-
      [handler] new handler Kanku::Handler::Vagrant
    - |-
      [templates] new VM templates
      - bios-serial-bridge.tt2
      - bios-serial-network.tt2
    - |-
      [cli] up - new aliases for option `--skip_all_checks`
      - `--sac`
      - `--skip-all-checks`
  fixes:
  unsorted:
    - |-
      [cli] change default loglevel to `INFO`
    - |-
      [examples] deleted KankuFile examples (migrated to https://hub.kanku.info)
    - |-
      [util] new method Kanku::Util::get_arch
    - |-
      [web] add filter `state` to guest list filter
    - |-
      [cli] use Kanku::Config::Defaults in Kanku::Cli 
    - |-
      [util] VM::Console - fallback to wicked/nmcli if 'ip' not installed
    - |-
      [defaults] `use_9p` default setting now configurable in kanku-config.yml
  examples:

---
