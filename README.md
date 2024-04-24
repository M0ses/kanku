# Sources of kanku website

In this branch you can find the source code of the [kanku website](https://m0ses.github.io/kanku/).

## Framework

The kanku website is using the [Statocles framework](http://preaction.me/statocles/) including the 
[blogging application](http://preaction.me/statocles/pod/Statocles/App/Blog/). 

Statocles is a static website generator written in perl.

## Contributing

### Development VM

To make contributors/reviewers lifes easier there is a KankuFile which will

* deploy a openSUSE Tumbleweed kanku VM
* add the OBS repository [home:M0ses:perl](https://build.opensuse.org/project/show/home:M0ses:perl)
* install [perl-Statocles] from [home:M0ses:perl](https://build.opensuse.org/project/show/home:M0ses:perl)
* start the statocles daemon.

```
    # Deploy the kanku VM
    kanku up

    # To start the webserver use the following command
    # To exit press <CTRL-C>
    # It will print out the following line after starting up the webserver:
    #
    # Listening on http://0.0.0.0:80
    #
    kanku ssh -u root -T force -e "cd /tmp/kanku; statocles build;statocles daemon -p 80"

    # 
    # To visit the webpage served by the new VM you only need to paste the ip in your browser.
    # URL:
    # http://<VM_IP>
```

### Creating a new blog post

TODO: documentation

### Creating a new release

TODO: documentation

