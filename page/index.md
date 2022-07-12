---
title: Kanku
---
# What is <%= $self->title %>?

kanku is designed to give you a better integration of your 
[kiwi](https://osinside.github.io/kiwi/) images built by the 
[Open Build Service](http://openbuildservice.org) 
in your development and testing workflow.

You can find pre-build images for various linux distribution in 
[devel:kanku:images](https://build.opensuse.org/project/show/devel:kanku:images)

## Modes

kanku can run in two modes

* **Developer mode** (on your laptop/workstation) while developing.
* **Server mode** (on a dedicated Server for QA) to run jobs periodically or triggerd by e.g. events on a rabbitmq bus.

### Developer mode

In a simple configuration file in YAML format you can specify the location of your kiwi image and actions to be executed after downloading the image and starting a Virtual Machine using the downloaded image.
You can configure one or multiple jobs per project. 
These jobs consists of one or more tasks which use a handler module and the given options.
With the kanku command line tool you can easily

* create a new VM based on the configured image
* run commands on the VM via SSH or serial console
* use salt-ssh to configure your VM
* access the created VM via ssh
* share your project/source directory with the VM

### Server mode

In server mode you have three ways to trigger a job:

* scheduled - kanku-scheduler triggers the job in a defined time period
* triggerd  - kanku-triggerd triggers the job at a defined event (e.g. via  rabbitmq)
* manually  - You can trigger a job via the WebUI

As the job configuration is very similar to the developer mode,
you can easily adopt the configurations used in developer mode.

The results can be shown via WebUI or with the kanku command line tool in a terminal

<!--

<div class="orbit" role="region" aria-label="Screenshots" data-orbit>
  <ul class="orbit-container">
    <button class="orbit-previous"><span class="show-for-sr">Previous Slide</span>&#9664;&#xFE0E;</button>
    <button class="orbit-next"><span class="show-for-sr">Next Slide</span>&#9654;&#xFE0E;</button>
    <li class="is-active orbit-slide">
      <img class="orbit-image" src="images/kanku_workflow.png" alt="Concept">
      <!-- <figcaption class="orbit-caption">Concept</figcaption> -->
    </li>
    <li class="is-active orbit-slide">
      <img class="orbit-image" src="images/screenshots/kanku_screenshot-guest_overview.png" alt="Guest Overview">
      <!-- <figcaption class="orbit-caption">Guest Overview.</figcaption> -->
    </li>
    <li class="orbit-slide">
      <img class="orbit-image" src="images/screenshots/kanku_screenshot-job_history.png" alt="Job History">
      <!-- <figcaption class="orbit-caption">Job History</figcaption> -->
    </li>
    <li class="orbit-slide">
      <img class="orbit-image" src="images/screenshots/kanku_screenshot-job_list-1.png" alt="Job List">
      <!-- <figcaption class="orbit-caption">Job List</figcaption> -->
    </li>
    <li class="orbit-slide">
      <img class="orbit-image" src="images/screenshots/kanku_screenshot-job_list-2.png" alt="Job List 1">
      <!-- <figcaption class="orbit-caption">Job List 1</figcaption> -->
    </li>
    <li class="orbit-slide">
      <img class="orbit-image" src="images/screenshots/kanku_screenshot-job_list-3.png" alt="Job List 2">
      <!-- <figcaption class="orbit-caption">Job List 2</figcaption> -->
    </li>
  </ul>

  <nav class="orbit-bullets">
    <button class="is-active" data-slide="0"><span class="show-for-sr">First slide details.</span><span class="show-for-sr">Current Slide</span></button>
    <button data-slide="1"><span class="show-for-sr">Second slide details.</span></button>
    <button data-slide="2"><span class="show-for-sr">Third slide details.</span></button>
    <button data-slide="3"><span class="show-for-sr">Fourth slide details.</span></button>
    <button data-slide="4"><span class="show-for-sr">Fifth slide details.</span></button>
  </nav>
</div>
-->
