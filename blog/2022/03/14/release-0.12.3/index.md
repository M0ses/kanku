---
title: RELEASE 0.12.3
date: 2022-03-14 08:43:00
tags: release
template: blog/release-post.html
data:
  release: 0.12.3
  warnings: |-
            ## ATTENTION:

            because instead of using iptables/ss/netstat directly we now use
            wrapper scripts with need to be added to the sudoers file.

            If you run kanku in developer mode you should re-run

            ```kanku setup --devel```
  features:
    - "[cli] check_configs command now also check job_group configs"
  fixes:
    - "[web] fix outdated cached settings in 'Job Groups'"
    - "[core] #boo 1196604 - wrapper scripts for iptables/ss/netstat"
    - "[dist] change default logging to stderr/journald"
    - "[util] VM::Image - use new buffer size while uncompressing"
    - "[urlwrapper] fixed x-scheme-handler_kanku"
    - "[handler] central config for host_interfaces for PortForward"
    - "[web] job groups config changes are now detected in web ui"
---
