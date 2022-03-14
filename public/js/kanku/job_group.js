Vue.component('job-group-card',{
  props: ['job_group', 'is_admin', 'job_group_init'],
  data: function() {
    this.restoreSettings();
    return {
      allJobs: this.allJobs || {jobs:[], digest:undefined},
      digest: this.digest || "",
      showGroupList: 0
    }
  },
  methods: {
    toggleDetails: function() {
      this.showGroupList = !this.showGroupList;
    },
    saveSettings: function() {
      var currentSettingsString = localStorage.getItem("kanku_job_group");
      if (!currentSettingsString) { currentSettingsString = "{}" }
      var currentSettings = JSON.parse(currentSettingsString);
      currentSettings[this.job_group.name] = this.allJobs;
      currentSettingsString = JSON.stringify(currentSettings);
      console.log(currentSettingsString)
      localStorage.setItem("kanku_job_group", currentSettingsString);
    },
    restoreSettings: function() {
      console.log("Started restoreSettings");
      console.log("job_group: " + this.job_group.name);
      var currentSettingsString = localStorage.getItem("kanku_job_group");
      var currentSettings;
      if (!currentSettingsString) {
	currentSettings = new Object();
	this.restoreDefaults();
      } else {
	currentSettings = JSON.parse(currentSettingsString);
        if (
          !currentSettings[this.job_group.name] ||
          currentSettings[this.job_group.name].digest != this.job_group.digest
        ) {
          this.restoreDefaults();
        } else {
          this.allJobs = currentSettings[this.job_group.name];
        }
      }
      console.log("restoreSettings this.allJobs :");
      console.log(this.allJobs);
    },
    restoreDefaults: function() {
      console.log("Started restoreDefaults");
      this.allJobs = {jobs:[], digest:this.job_group.digest};
      console.log("Started restoreDefaults for "+this.job_group.name);
      console.log(this.job_group);
      var jgl =  Object.keys(this.job_group.groups).length;
      console.log("jgl:")
      console.log(jgl)
      for (let i=0; i < jgl;i++) {
        console.log("blah (i): "+i);
        console.log(this.job_group.groups[i]);
	this.allJobs.jobs[i]=new Array();
	var groups_count = this.job_group.groups[i].jobs.length;
	for (let a=0; a < groups_count;a++) {
          console.log("blah (i)(a): "+a);
	  this.allJobs.jobs[i][a]=true;
	}
      }
      console.log("restoreDefaults this.allJobs:");
      console.log(this.allJobs);
      this.saveSettings();
    },
    triggerJobGroup: function() {
      var jg_name = this.job_group.name;
      var url    = uri_base + "/rest/job_group/trigger/"+this.job_group.name+".json";
      console.log(this.allJobs);
      this.saveSettings();
      var data = this.allJobs.jobs;
      axios.post(url, { data: data, is_admin: this.is_admin}).then(function(response) {
        show_messagebox(response.data.state, response.data.msg);
      });
    }
  },
  template: ''
    + '<div class="card" style="margin-bottom:5px;">'
    + ' <div class="card-header">'
    + '  <show-details @toggleDetails="toggleDetails()"></show-details>'
    + '  <span class="badge badge-secondary">{{ job_group.name }}</span>'
    + ' </div>'
    + ' <form :id="job_group.name">'
    + ' <div class="card-body" v-show="showGroupList">'
    + '  <div class=job_task_list>'
    + '   <div'
    + '    v-for="(group, i) in job_group.groups"'
    + '    v-bind:group="group"'
    + '    >'
    + '      <div class=group-card>'
    + '      <h4><span class="badge badge-secondary" style="display:block;" v-on:click="showValues()">{{ group.description }}</span></h4>'
    + '      <input type=hidden name="description" :value="group.description">'
    + '      <div class="form-group">'
    + '        <div v-for="(c,a) in group.jobs">'
    + '         <input type=checkbox v-model="allJobs.jobs[i][a]"> <label>{{ c }}</label>'
    + '        </div>'
    + '     </div>'
    + '     </div>'
    + '   </div>'
    + '  </div>'
    + ' </div>'
    + ' <div class="card-footer">'
    + '  <div class="btn btn-success btn-sm" v-on:click="triggerJobGroup()">'
    + '   Trigger JobGroup'
    + '  </div>'
    + '  <div class="btn btn-primary btn-sm" v-on:click="restoreDefaults()">'
    + '   Restore Defaults'
    + '  </div>'
    + ' </div>'
    + ' </form>'
    + '</div>'
});

const jobGroupPage = {
  props: ['user_id', 'is_admin'],
  data: function() {
    return {
      job_groups:    [],
      original_jobs: [],
      filter:        this.$route.query.filter,
      page:          1,
      total_pages:   0,
      limit:         10,
    };
  },
  methods: {
    refreshPage: function() {
      var url    = uri_base + "/rest/gui_config/job_group.json";
      var self   = this;
      var params = {
        filter: this.filter,
        limit:  self.limit,
        page:   this.page,
      };
      self.job_groups  = [];
      $('#spinner').show();
      axios.get(url, { params: params }).then(function(response) {
	self.job_groups = response.data.config;
        var tp_float = response.data.total_entries / response.data.limit;
        var tp_int   = Math.floor(tp_float);
        self.total_pages = (tp_float > tp_int) ? tp_int + 1 : tp_int;
      }).catch(function (error) {
        // handle error
        show_messagebox('danger', "URL: " + url + "<br>" +error, timeout=0);
      }).then(function () {
        $('#spinner').hide();
      });
    }
  },
  mounted: function() {
      this.refreshPage();
  },
  template: ''
    + '<div>'
    + ' <div v-if="user_id">'
    + '  <head-line text="Job Group"></head-line>'
    + '  <div class="row top_pager">'
    + '   <search-field :filter="filter" @search-term-change="refreshPage" comment="Filter Job Groups by regex"></search-field>'
    + '   <div class="col-md-4">'
    + '   </div>'
    + '   <limit-select @updatePage="refreshPage" selected_limit="limit"></limit-select>'
    + '   <div class="col-md-2">'
    + '     <refresh-button @refreshPage="refreshPage"></refresh-button>'
    + '   </div>'
    + '  </div>'
    + '  <div>'
    + '  <spinner></spinner>'
    + '  </div>'

    + '  <job-group-card v-for="job_group in job_groups" v-bind:key="job_group.name" v-bind:job_group="job_group" :is_admin="is_admin"></job-group-card>'
    + '  <div id=bottom_pager class=row>'
    + '   <div class="col-md-4"></div>'
    + '   <div class="col-md-4">'
    + '    <paginator :page="page" :total_pages="total_pages" @updatePage="refreshPage"></paginator>'
    + '   </div>'
    + '   <div class="col-md-4"></div>'
    + '  </div>'

    + ' </div>'
    + ' <div v-else>'
    + '  <h1>Please Login!</h1>'
    + ' </div>'
    + '</div>'
};
