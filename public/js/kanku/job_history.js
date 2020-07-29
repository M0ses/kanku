Vue.component('limit-select',{
  data: function() {
    return {limit:10}
  },
  methods: {
    setNewLimit: function() {
      this.$parent.limit = this.limit;
      this.$emit('updateJobHistoryPage');
    }
  },
  template: ''
    + '<div @change="setNewLimit()" class="col-md-2">'
    + '  Show rows:'
    + '  <select v-model="limit">'
    + '    <option v-for="option in [5,10,20,50,100]" :value="option">{{ option }}</option>'
    + '  </select>'
    + '</div>'
});

Vue.component('search-tooltip-job_history',{
  template: ''
    + '<span class="badge badge-primary" style="padding: 0.6rem;" data-toggle="tooltip" data-placement="bottom" '
    + ' title="<strong>Search by job_name:</strong><br>Use &apos;%&apos; as wildcard<br>'
    + '        <strong>Supported fields:</strong><br>id, state, name, worker<br>'
    + '        <strong>Supported Values:</strong><br>comma separated lists (except worker)<br>'
    + '        <strong>Examples:<br></strong>&apos;id:1,2&apos;, &apos;state:running&apos;, &apos;name=obs-server,kanku-devel&apos;, &apos;obs-server%&apos;">'
    + ' <i class="fas fa-question-circle fa-2x" ></i>'
    + '</span>'
});

Vue.component('job-state-checkbox',{
  props: ['name','state_class'],
  data: function() {
    return {job_states: this.$route.query.job_states || ['succeed','failed','dispatching','running']}
  },
  methods: {
    updateJobSearch: function() {
      this.$root.$emit('toggle_state', this.name);
      var q2 = this.$route.query || {};
      var q  = {...q2, job_states:this.job_states};
      this.$router.push({ path: this.$router.currentPath, query: q});
      this.$emit('updateJobHistoryPage');
    },
  },
  template: ''
    + '<div class="col col-md-3">'
    + ' <h5>'
    + '  <input type="checkbox" name="state" v-model="job_states" v-bind:value="name" class="cb_state" v-on:change="updateJobSearch" >'
    + '  <span v-bind:class="state_class">{{ name }}</span>'
    + ' </h5>'
    + '</div>'
});

Vue.component('show-only-latest-results',{
  data: function() {
    return { show_only_latest_results : this.$route.query.show_only_latest_results };
  },
  methods: {
    updateJobSearch: function() {
      this.$root.$emit('toggle_show_only_latest_results');
      var q2 = this.$route.query || {};
      var q  = {...q2};
      if (this.show_only_latest_results) {
        q['show_only_latest_results'] = true;
      } else {
        delete q['show_only_latest_results'];
      }
      this.$router.push({ name: 'job_history', params: {page: 1}, query: q});
      this.$emit('updateJobHistoryPage');
    },
  },
  template: ''
    + '<div class="col col-md-3">'
    + ' Show only latest results'
    + ' <input type="checkbox" name="show_only_latest_results_cb" @change="updateJobSearch" style="margin:7px" v-model="show_only_latest_results">'
    + '</div>'
});

Vue.component('job-history-list',{
  props: ['jobs', 'is_admin', 'show_comments'],
  template: ''
    + '<div>'
    + ' <job-history-card v-for="job in jobs" :key="job.id" :job="job" :is_admin="is_admin" :show_comments="show_comments"></job-history-card>'
    + '</div>'
});

Vue.component('paginator', {
  props: ['page', 'is_admin', 'total_pages'],
  methods: {
    nextpage: function() {
      this.$parent.page++;
      router.push({name: 'job_history', params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updateJobHistoryPage');
    },
    prevpage: function() {
      this.$parent.page--;
      router.push({name: 'job_history', params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updateJobHistoryPage');
    },
    firstpage: function() {
      this.$parent.page = 1;
      router.push({name: 'job_history', params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updateJobHistoryPage');
    },
    lastpage: function() {
      this.$parent.page = this.total_pages;
      router.push({name: 'job_history', params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updateJobHistoryPage');
    }
  },
  computed: {
    pb_classes: function() { return (this.page > 1) ? ['page-item'] : ['page-item', 'disabled'] },
    nb_classes: function() { return (this.total_pages > this.page) ? ['page-item'] : ['page-item', 'disabled'] },
  },
  template: ''
    + '<nav aria-label="Pagination">'
    + '  <ul class="pagination">'
    + '    <li class="page-item">'
    + '      <span class="page-link" @click="firstpage()">First</span>'
    + '    </li>'
    + '    <li :class="pb_classes">'
    + '      <span class="page-link" @click="prevpage()">Previous</span>'
    + '    </li>'
    + '    <li class="page-item active">'
    + '      <span class="page-link">'
    + '        {{ page }}/{{ total_pages }}'
    + '        <span class="sr-only">(current)</span>'
    + '      </span>'
    + '    </li>'
    + '    <li :class="nb_classes">'
    + '      <span class="page-link" @click="nextpage()">Next</span>'
    + '    </li>'
    + '    <li class="page-item">'
    + '      <span class="page-link" @click="lastpage()">Last</span>'
    + '    </li>'
    + '  </ul>'
    + '</nav>'
});

const jobHistoryPage = {
  props:['is_admin'],
  data: function() {
    var js = {'succeed':1, 'failed':1,'dispatching':1,'running':1,'scheduled':0,'triggered':0,'skipped':0};
    if (this.$route.query.job_states) {
      var tmp = {};
      this.$route.query.job_states.forEach(function (item, index) { tmp[item] = 1; });
      for (let key in js) {
        js[key] = tmp[key] || 0;
      }
    }
    return {
      jobs: {},
      page: this.$route.params.page,
      limit: 10,
      filter: this.$route.query.filter,
      job_states: js,
      show_only_latest_results : this.$route.query.show_only_latest_results,
      this: this,
      total_pages: 1,
    };
  },
  computed: {
    show_comments: function() {return this.$parent.show_comments },
  },
  created() {
    this.$root.$on('toggle_state', state => {
      this.job_states[state] = ! this.job_states[state];
    });
    this.$root.$on('toggle_show_only_latest_results', value => {
      this.show_only_latest_results = !this.show_only_latest_results;
    });
  },
  methods: {
    refreshPage: function() {
      $('#spinner').show();
      var url    = uri_base + "/rest/jobs/list.json";
      var self   = this;
      self.page  = this.$route.params.page;
      this.jobs  = {};
      var params = {};
      var params = new URLSearchParams();
      params.append("page",  self.page);
      params.append("limit", self.limit);

      if (this.show_only_latest_results) { params.append("show_only_latest_results",  1); }

      if (self.filter) { params.append('filter', self.filter); }

      for (key in self.job_states) {
        if (self.job_states[key]) { params.append("state", key); }
      };
      axios.get(url, { params: params })
        .then(function(response) {
	  response.data.jobs.forEach(function(job) {
	    calc_additional_job_parameters(job);
	  });
	  self.jobs = response.data.jobs;
          var tp_float = response.data.total_entries / response.data.limit;
          var tp_int   = Math.floor(tp_float);
          self.total_pages = (tp_float > tp_int) ? tp_int + 1 : tp_int;
        })
        .catch(function (error) {
          show_messagebox('danger', error);
          console.log(error);
        })
        .then(function () {
          $('#spinner').hide();
	  $(function () {
	    $('[data-toggle="tooltip"]').tooltip({html:true})
	  });
        }
      );
    }
  },
  mounted: function() {
    this.refreshPage();
  },
  template: ''
    + '<div>'
    + '  <head-line text="Job History"></head-line>'
    + '  <div class="row top_pager">'
    + '    <job-state-checkbox name="succeed"     state_class="badge badge-success" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <job-state-checkbox name="failed"      state_class="badge badge-danger"  @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <job-state-checkbox name="dispatching" state_class="badge badge-primary" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <job-state-checkbox name="running"     state_class="badge badge-primary" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '  </div>'
    + '  <div class="row top_pager">'
    + '    <job-state-checkbox name="scheduled"   state_class="badge badge-warning" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <job-state-checkbox name="triggered"   state_class="badge badge-warning" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <job-state-checkbox name="skipped"     state_class="badge badge-warning" @updateJobHistoryPage="refreshPage"></job-state-checkbox>'
    + '    <div class="col col-md-3">'
    + '    </div>'
    + '  </div>'
    + '  <div class="row top_pager">'
    + '   <search-field :filter="filter" @search-term-change="refreshPage" comment="Enter search term - SEE Tooltips for details"></search-field>'
    + '   <search-tooltip-job_history></search-tooltip-job_history>'
    + '   <show-only-latest-results  @updateJobHistoryPage="refreshPage"></show-only-latest-results>'
    + '   <limit-select @updateJobHistoryPage="refreshPage" selected_limit="limit"></limit-select>'
    + '   <div class="col-md-2">'
    + '    <refresh-button @refreshPage="refreshPage"></refresh-button>'
    + '   </div>'
    + '  </div>'
    + '  <div>'
    + '   <job-history-header></job-history-header>'
    + '   <spinner></spinner>'
    + '   <job-history-list :jobs="jobs" :is_admin="is_admin" :show_comments="show_comments"></job-history-list>'
    + '  </div>'
    + '  <div id=bottom_pager class=row>'
    + '   <div class="col-md-4"></div>'
    + '   <div class="col-md-4">'
    + '    <paginator :page="page" :total_pages="total_pages" @updateJobHistoryPage="refreshPage"></paginator>'
    + '   </div>'
    + '   <div class="col-md-4"></div>'
    + '  </div>'
    + '</div>'
};
