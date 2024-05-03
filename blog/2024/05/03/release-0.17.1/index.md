---
title: RELEASE 0.17.1
date: 2024-05-03 15:07:39
tags: release
template: blog/release-post.html
data:
  release: 0.17.1
  features:
    - |-
      [setup] [Closes: #44](https://github.com/M0ses/kanku/issues/44) Write systemd network config
    - |-
      [cli] add option `--pseudo_terminal` to the `ssh` command
    - |-
      [cli] Feature: print randomized passwords at the end of `kanku up`
    - |-
      [handler] CreateDomain: new option 'no_wait_for_bootloader'
    - |-
      [examples] add KankuFile.openSUSE-Leap-15.5-official + Signature
    - |-
      [examples] add KankuFile.openSUSE-Tumbleweed-sdboot + Signature
    - |-
      [templates] new VM template: vm-x86_64-uefi-tpm2.0.tt2
    - |-
      [templates] init.tt2: add Kanku::Handler::CopyProfile
    - |-
      [doc] enhance CONTRIBUTING.md
    - |-
      [core] made Kanku::Config::Defaults "setup" ready

      - add defaults for
        - Kanku::Setup::Devel
          - Kanku::Setup::Server::Distributed
          - Kanku::Setup::Server::Standalone
  fixes:
    - |-
    - |-
      [cli] return rc > 0 if `kanku up` fails
    - |-
      [core][fix] improvements for Kanku::Config::Defaults

      - Better handling if empty defaults
      - merge default settings with configured settings instead of overwriting defaults
    - |-
      [setup] use libvirt network name as  bridge name
    - |-
      [util] VM: log domain XML only on error
    - |-
      [util] CurlHttpDownload: create cache_dir before download if dir not exists
    - |-
      [dist] change Net::OBS::Client version to 0.1.3
    - |-
      [templates] cleanup existing VM templates
    - |-
      [dist] added templates to install in Makefile
    - |-
      [core] cleanup cpio api leftovers

---
