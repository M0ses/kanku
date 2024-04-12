# RELEASE 0.17.0


<h2>Attention:</h2>
<p>
   <b>Focus of this release has been:</b>
</p>
<ul>
  <li>Support for new URL protocol (based on https) <pre><code>kankus://khub.example.com/path/to/KankuFile</code></pre></li>
  <li>improve packaging for rpm and deb based distros</li>
  <li>refactor LWP::UserAgent based libraries to use Net::OBS::Client/Net::OBS::LWP/UserAgent which supports experimental <a href="https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12" target='_blank'>'Signature' HTTP Authentication Scheme</a></li>
  <li>cleanup deprecated/obsolete/broken libraries</li>
</ul>
<p>
   <b>
   The following libraries have been deleted.<br>
   Please check your configs for the following Handlers:
   </b>
</p>
<ul>
  <li>Kanku::Handler::OBSDownload <b>(use Kanku::Handler::ImageDownload)</b></li>
  <li>Kanku::Handler::OpenStack::CreateInstance (discontinued w/o replacement)</li>
  <li>Kanku::Handler::OpenStack::Image (discontinued w/o replacement)</li>
  <li>Kanku::Handler::OpenStack::RemoveInstance (discontinued w/o replacement)</li>
</ul>
<p>
  The following libraries have been also removed.
  This should only be relevant for kanku developers.
  Kanku users should not notice these changes:
</p>
<ul>
  <li>Kanku::Util::HTTPMirror</li>
  <li>OpenStack::API</li>
  <li>OpenStack::API::Cinder</li>
  <li>OpenStack::API::EC2</li>
  <li>OpenStack::API::Glance</li>
  <li>OpenStack::API::Neutron</li>
  <li>OpenStack::API::Nova</li>
  <li>OpenStack::API::Quantum</li>
  <li>OpenStack::API::Role::Client</li>
  <li>OpenStack::API::Role::Service</li>
</ul>

## FEATURES

* [dist] new package 'kanku-iptables' (Store and restore kanku iptables rules)
* [dist] added x-scheme-handler kankus://
* [core] configurable SigAuth for http(s) dependent libraries, e.g.:
- `Kanku::Handler::OBSCheck`
- `Kanku::Handler::ImageDownload`
- `Kanku::Util::CurlHttpDownload`
* [dist] improvments for rpm/debian packages
* [test] updated libraries in base check
* [dist] new kanku job 'test' to create a vm running kanku test suite
* [handler] removed obsolete OpenStack handler and modules
* [handler] OBSCheck: setter for api_url for later use
* [handler] removed deprecated K::H::OBSDownload
* [templates] examples for Net::OBS::Client authentication
* [util] deleted Kanku::Util::HTTPMirror


## BUGFIXES

* [handler] fix skip_all_checks in OBSCheck
* [util] DoD: fixed auth problem
* [dist] fix mkdir for system-user-kankurun.conf
* [dist] more fixes for spec



<h3>Example configuration for SigAuth</h3>
<p>
   Add the following config snippet to your kanku config:
</p>
<ul>
  <li><code>~/.kanku/kanku-config.yml</code> (devel mode)</li>
  <li><code>/etc/kanku/kanku-config.yml</code> (server mode)</li>
</ul>
<p>
   Net::OBS::SigAuth will try to find a private key to sign
   your request in the following order
</p>
<ul>
  <li>first key in ssh-agent (SEE <code>ssh-add -L</code>)</li>
  <li><code>~/.ssh/id_ed25519</code></li>
  <li><code>~/.ssh/id_rsa</code></li>
</ul>
<pre><code>
Net::OBS::Client:
  credentials:
    https://obs.example.com:
      sigauth_credentials:
        user: Bob
</code></pre>
<p>
  SEE <a target="_blank" href="https://github.com/M0ses/kanku/blob/a05871f15979138f2e55976bf6be8c3cc21e8add/etc/templates/cmd/setup/kanku-config.yml.tt2#L174">etc/templates/cmd/setup/kanku-config.yml.tt2</a> for more configuration examples.
</p>


