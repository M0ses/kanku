---
title: RELEASE 0.12.0
date: 2022-02-09 07:40:24
tags: release
template: blog/release-post.html
data:
  release: 0.12.0
  features:
    - "[web] new switch autostart to create persistent VM's"
    - "[web] added login route (for GET method)"
    - "[cli] new command <code>kanku snapshot ...</code>"
    - "[cli] new option: <code>kanku ssh --ipaddress ...</code> - alias <code>-i</code>"
    - "[cli] new option: <code>kanku ssh --execute ...</code> - alias <code>-e</code>"
    - "[cli] use ssh_user from KankuFile for ssh command"
    - "[cli] new option: <code>--log_file/--log_stdout</code> for VM related commands"
    - "[cli] Suggest running ssh-add on auth fauilure when auth_type is 'agent'"
  fixes:
    - "[web] fix 'show only latest' in job history"
    - "[core] no_wait_for_bootloader for ExecuteCommandsViaConsole to avoid waiting for bootloader"
    - "[core] Fix ssh key filename: id_ecdsa.pub_sk -&gt; id_ecdsa_sk.pub"
    - "[core] various cleanups to avoid 'uninitialized value'"
    - "[dist] fix tabs in default config template setup/kanku-config.yml.tt2"
    - "[handler] K:H:PrepareSSH: fix permissions for user kanku"
    - "[handler] K:H:CleanupIPTables: cleanup unused packages"
    - "[util] set default for running_remotely in VM to 0"
    - "[examples] updated to current opensuse"
    - "[examples] deleted broken examples"
    - "[examples] updated centos to latest version"
    - "[examples] renamed centos -> centos-current"
  examples: |-
            <p>This release containes a full functional version of the "Kanku VM Autostart" feature for kanku clusters.</p>
            <ul>
              <li>Restart VMs</li>
              <li>Restore VMs iptable rules</li>
            </ul>
            <img src="img/kanku_screenshot-feature-autostart_domain.png">
---
