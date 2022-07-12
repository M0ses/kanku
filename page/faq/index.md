# FAQ


## Where can I find kanku images?

Have a look at [devel:kanku:images](https://build.opensuse.org/project/show/devel:kanku:images)
to get an overview of pre-built kanku images or use ```kanku lsi```

Keep in mind how to configure the selected image in kanku

    -
      use_module: Kanku::Handler::OBSCheck
      options:
        api_url: https://api.opensuse.org
        project: devel:kanku:images
        # package e.g. openSUSE-Tumbleweed-JeOS:ext4
        package: <package name>
        # e.g. images_leap_15_0
        repository: <repository name>

## Where can I find further documentation?

* ```perldoc Kanku```
* [Online POD Documentation](/pod/Kanku.html)
* [Kanku Cheatsheet](https://www.cheatography.com/m0ses/cheat-sheets/kanku/)

## KNOWN ISSUES

Please see the open issues on [Github](https://github.com/M0ses/kanku/issues)
