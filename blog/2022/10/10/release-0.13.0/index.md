---
title: RELEASE 0.13.0
date: 2022-10-10 13:15:00
tags: release
template: blog/release-post.html
data:
  release: 0.13.0
#  warnings: |-
#            <h2>Attention:</h2>
#            <p></p>
#            <code></code>
  features:
#    - "[core|web|util|handler|cli] "
    - "[core] refactored rabbmitmq handling in worker and dispatcher"
    - "[handler] Reboot: new option 'login_timeout' to wait for console"
    - "[handler] SaltSSH: added multiple attributes"
    - "[dist] removed kanku-web.log from default logging conf"
    - "[dist] remove logrotate config - now done with journald"
    - "[cli] ssh: new parameter --x11_forward/-X to enable ssh x11 forwarding"
#  fixes:
#    - "[core|web|util|handler|cli] "
  examples: |-
            <h3>Examples</h3>
            <h4>X-Forwarding for `kanku ssh`</h4>
            <code>kanku ssh -X</code>
#            <img src="img/kanku-1.jpg" alt="Image 1">
#            <code>command</code>
---
