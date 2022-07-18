---
title: RELEASE 0.12.6
date: 2022-06-22 10:09:52
tags: release
template: blog/release-post.html
data:
  release: 0.12.6
  features:
    - "[cli] up: new special job `__ALL__` where a sequence of jobs can be defined in an array"
    - "[cli] up: multiple jobs can now be specified as options"
    - "[handler] new Kanku::Handler::CopyProfile"
  examples: |-
            ## EXAMPLES

            #### CLI: up - special configuration `__ALL__`

            In KankuFile:


                domain_name: saltmaster
                default_job: saltmaster

                jobs:
                  __ALL__:
                    - clean
                    - saltmaster
                    - admin-hosts
                    - service-servers
                    ...
                  clean:
                    ...
                  saltmaster:
                    ...
                  service-servers:
                    ...
                  ...


            On the cli:

            ```kanku up -j __ALL__ -S```

            #### CLI: up - specify multiple jobs in one command line

            ```kanku up -j job1 -j job2```

            #### Handler: Kanku::Handler::CopyProfile

            To use this Handler you need a configuration section in your
            ~/.kanku/kanku-config.yml like the following to specify the commands
            which should be executed


                Kanku::Handler::CopyProfile:
                  user: kanku
                  tasks:
                    - cmd: cp
                      src: ~/.gitconfig
                    - cmd: cp
                      src: ~/.vimrc
                    - cmd: cp
                      src: ~/.vim/
                      recursive: 1
                    - cmd: mkdir
                      path: ~/.config/
                    - cmd: cp
                      src: ~/.config/osc/
                      dst: ~/.config/osc/
                      recursive: 1
                    - cmd: chown
                      owner: kanku:users
                      recursive: 1
                      path: ~/.config/
                    - cmd: chmod
                      mode: 700
                      path: ~/.config/


            And you need an entry in your KankuFile job, where you can specify the users
            for which this profile should be copied.


                jobs:
                  default_job:
                    ...
                    -
                      use_module: Kanku::Handler::CopyProfile
                      options:
                        users:
                          - root
                          - kanku


             ATM the following commands (cmd) are available:```

             * mkdir
             * cp
             * chmod
             * chown
---
