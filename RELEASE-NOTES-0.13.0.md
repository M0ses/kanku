# RELEASE 0.13.0

## FEATURES

* [core] refactored rabbmitmq handling in worker and dispatcher
* [handler] Reboot: new option 'login_timeout' to wait for console
* [handler] SaltSSH: added multiple attributes
* [dist] removed kanku-web.log from default logging conf
* [dist] remove logrotate config - now done with journald
* [cli] ssh: new parameter --x11_forward/-X to enable ssh x11 forwarding



<h3>Examples</h3>
<h4>X-Forwarding for `kanku ssh`</h4>
<code>kanku ssh -X</code>


