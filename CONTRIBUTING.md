# Welcome to kanku contributing guidelines

Thanks for your intrest in contributing to kanku.
You can either contribute code, docs, blog posts or improvements to our [website](https://m0ses.github.io/kanku/).

**Please, Please, PLEASE!!!** get in contact with us before starting implementation.

## code

1. Please open an [Github Issue](https://github.com/M0ses/kanku/issues)
2. Explain what you would like to contribute to avoid frustration while the review phase.
3. Fork the kanku project
4. Start your development in the development branch (master)
4. Create a pull request
5. Request a review

## docs

Kanku modules are documented with perl's POD (Plain Old Documentation) inside the code/modules.

Please read also the Code Section above.

## blog posts/website

The website is built with the static website generator [Statocles](http://preaction.me/statocles/).
Sources can be found in the `gh-pages-src` branch in this repository.
For more information check out the [README.md in gh-pages-src](https://github.com/M0ses/kanku/tree/gh-pages-src)

## How to write your comments

### Prefixes

#### Database

* [schema] -

### Core Classes/Components

* [core]
  * [dispatcher]
  * [scheduler]
  * [triggerd]
  * [cli]
  * [web]
  * [worker]

### Handler and Helper Classes

* [handler]
* [util]

### Other

* [logging]
* [setup]
* [config]
* [critic]
* [dist]
* [doc]
