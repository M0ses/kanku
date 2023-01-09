var alert_map = {
  succeed:     'alert-success',
  failed:      'alert-danger',
  running:     'alert-primary',
  dispatching: 'alert-primary',
  skipped:     'alert-warning',
};

function show_messagebox(state, msg, timeout=10000) {
  var elem = $("#messagebox");
  var div = $('<div class="alert-' + state +' kanku_alert alert-dismissible fade show" role=alert></div>').append(msg);
  div.append('<button type="button" class="close" data-dismiss="alert">&times;</button>');
  elem.append(div);
  if(timeout) {
    var intervalID = setTimeout(function() { div.remove(); }, timeout);
  }
}

function calc_job_start_and_end(start_time, end_time) {
  if (start_time > 0) {
    var st = new Date(1000 * start_time);
    // calculate duration
    var due;

    if ( end_time ) {
      due = end_time;
    } else {
      due = Math.floor(Date.now() / 1000);
    }

    var duration = due - start_time;
    duration_min = Math.floor( duration / 60 );
    duration_sec = duration % 60;

    // (start_time_formatted, duration_formatted)
    return [st.toLocaleString(), duration_min +" min "+duration_sec+" sec"];
  } else {
    return ["not started", "not started"];
  }
}

function calc_additional_job_parameters(job) {
        job.state_class = alert_map[job.state];
        var r = calc_job_start_and_end(job.start_time, job.end_time);
        job.start_time_formatted = r[0];
        job.duration             = r[1];
        var ct = new Date(1000 * job.creation_time);
        job.creation_time_formatted = ct.toLocaleString();
};

Vue.component('help-button',{
  template: `
    <button class="btn btn-primary float-right pull-right" style="margin-left: 5px; padding: 0.6rem;" @click="$emit('showHelp')">
     <i class="fas fa-question-circle"></i>
    </button>`
});

Vue.component('refresh-button',{
  methods: {
    refreshPage: function() {
      this.$emit('refreshPage');
    }
  },
  template: ''
    + '<button type="button" class="btn btn-primary float-right pull-right" @click="refreshPage">'
    + '  <i class="fas fa-sync"></i> Refresh'
    + ' </button>'
});

Vue.component('spinner',{
  methods: {
    refreshJobList: function() {
      this.$root.updatePage();
    }
  },
  template: ''
    + '    <div class="row" id="spinner">'
    + '        <div class="col-md-5"></div>'
    + '        <div class="col-md-2">'
    + '          <div class="spinner-border" role="status">'
    + '            <span class="sr-only">Loading...</span>'
    + '          </div>'
    + '        </div>'
    + '        <div class="col-md-5"></div>'
    + '    </div>'
});

Vue.component('show-details',{
  methods: {
    toggleDetails: function() {
      this.showDetails = ! this.showDetails;
      this.$emit("toggleDetails");
    }
  },
  data: function() {
    return {
      showDetails: 0
    }
  },
  template: ''
    + '      <span v-on:click="toggleDetails()" style="color:black">'
    + '        <span v-show="!showDetails">'
    + '          <i class="fas fa-plus-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Show details"/></i>'
    + '        </span>'
    + '        <span v-show="showDetails">'
    + '          <i class="far fa-minus-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Hide details"/>'
    + '        </span>'
    + '      </span>'
});

Vue.component('to-top-button',{
  methods: {
    toTop: function() {
      window.scrollTo(0,0);
    }
  },
  template: ''
    + '<transition name="fade">'
    + ' <a id="back-to-top" href="#" class="back-to-top float-right" role="button" title="Click to return on the top page" data-toggle="tooltip" data-placement="left" @click="toTop">'
    + '  <span class="fa fa-arrow-circle-up fa-3x"></span>'
    + ' </a>'
    + '</transition>'
});

Vue.component('message-box',{
  props: ['message_bar'],
  template: ''
    + '<transition name="fade">'
    + '  <div v-if="message_bar.show" v-bind:class="message_bar.alert_class" class="alert">{{ message_bar.text }}</div>'
    + '</transition>'
});

Vue.component('message-box-placeholder', {
 template: '<div id="messagebox" class="container alert fixed-top" style="margin-top:50px;"></div>'
});

Vue.component('head-line', {
  props: ['text'],
  template: '<h1>{{ text }}</h1>'
});

Vue.component('worker-info',{
  props: ['worker', 'result', 'ct'],
  computed: {
    jobError: function() {
      if (this.result) {
        var res = JSON.parse(this.result);
	return res.error_message
      }
      return undefined;
    },
  },
  template: ''
    + '<div class="worker_info">'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker Name'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.host }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker PID'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.pid }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Worker Queue'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ worker.queue }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row">'
    + '    <div class="col-md-2">'
    + '      Job created'
    + '    </div>'
    + '    <div class="col-md-10">'
    + '      {{ ct }}'
    + '    </div>'
    + '  </div>'
    + '  <div class="row" v-show="worker.error">'
    + '    <div class="col-md-12">'
    + '      <pre>{{ worker.error }}</pre>'
    + '    </div>'
    + '  </div>'
    + '  <div class="row" v-show="jobError">'
    + '    <div class="col-md-12">'
    + '      <pre>{{ jobError }}</pre>'
    + '    </div>'
    + '  </div>'
    + '</div>'
});

Vue.component('job-history-task-card',{
  props: ['task'],
  data: function() {
    return {
      showDetails: 0
    }
  },
  methods: {
    toggleDetails: function() {
      this.showDetails = !this.showDetails;
    }
  },
  template:
    `
    <div class="card task_card">
      <div class="card-header alert" v-bind:class="task.state_class">
        <div class="row">
          <div class="col-md-12">
            <show-details @toggleDetails="toggleDetails()"></show-details>
            <span class="badge badge-secondary">{{ task.id }}</span> {{ task.name }}
          </div>
        </div>
      </div>
      <div class="card-body" v-show="showDetails">
        <task-result v-bind:result="task.result"></task-result>
      </div>
    </div>
    `
});

Vue.component('task-result',{
  props: ['result'],
  template: ''
    + '<div class=container>'
    + ' <template v-if="result.error_message">'
    + '  <pre>{{ result.error_message}}</pre>'
    + ' </template>'
    + ' <template v-if="result.prepare">'
    + '  <div class="row">'
    + '    <div class="col-md-2">prepare:</div><div class="col-md-10">{{ result.prepare.message }}</div>'
    + '  </div>'
    + ' </template>'
    + ' <template v-if="result.execute">'
    + '  <div class="row">'
    + '    <div class="col-md-2">execute:</div><div class="col-md-10">{{ result.execute.message }}</div>'
    + '  </div>'
    + ' </template>'
    + ' <template v-if="result.finalize">'
    + '  <div class="row">'
    + '    <div class="col-md-2">finalize:</div><div class="col-md-10">{{ result.finalize.message }}</div>'
    + '  </div>'
    + ' </template>'
    + '</div>'
});

Vue.component('task-list',{
  props: ['result', 'workerinfo', 'subtasks'],
  data: function() {
    return {
      isShown: 0,
      count: 0,
      jobData: {},
      ct: '',
    }
  },
  updated: function() {
    // Workaround if data gets updated but jobData is empty
    // like it happens when "Refresh" button is pressed
    if (! this.jobData.name) {
      return;
    }
    calc_additional_job_parameters(this.jobData);
    this.$parent.job.state_class          = this.jobData.state_class;
    this.$parent.job.start_time_formatted = this.jobData.start_time_formatted;
    this.$parent.job.duration             = this.jobData.duration;
    this.$parent.workerInfo.host          = this.jobData.workerhost;
    this.ct = this.jobData.creation_time_formatted;
  },
  template: ''
    + '<div class="card-body">'
    + ' <worker-info :worker="workerinfo" :result="result" :ct="ct"></worker-info>'
    + ' <job-history-task-card v-bind:key="task.id" v-bind:task="task" v-for="task in jobData.subtasks"></job-history-task-card>'
    +'</div>'
});

Vue.component('job-history-card',{
  props: ['job', 'is_admin', 'show_comments'],
  data: function () {
    return {
      showDetails:        0,
      uri_base:            uri_base,
      comment: '',
      subtasks: [],
    }
  },
  computed: {
    workerInfo: function() {
      var tmp = new Array;
      if (this.job.workerinfo) {
        tmp = this.job.workerinfo.split(':');
      }
      return {
        host:  tmp[0] || 'localhost',
        pid:   tmp[1] || 0,
        queue: tmp[2] || '',
        loglink: 'http://'+tmp[0]+'/kanku-console-logs/job-'+this.job.id+'-console.log',
      }
    },
    show_pwrand: function() {
      if (this.is_admin && this.job.pwrand && this.job.pwrand !='{}') { return true }
      return false;
    },
    comment_title: function() { return "Comment for Job "+this.job.id },
  },
  methods: {
    toggleDetails: function() {
      this.showDetails = !this.showDetails
      this.$refs.tasklist.isShown = ! this.$refs.tasklist.isShown;
      this.$refs.tasklist.count++;
      this.getJobDetails();
    },
    getJobDetails: function() {
      var url = uri_base + "/rest/job/"+this.job.id+".json";
      var self = this;
      axios.get(url).then(function(response) {
        self.$refs.tasklist.jobData = response.data;
        response.data.subtasks.forEach(function(task) {
           task.state_class = alert_map[task.state];
           task.result      = task.result || {};
        });
        self.substasks = response.data.subtasks;
      });
    },
    showModal: function() {
      this.$refs.modalComment.show()
    },
    closeModal: function() {
      this.$refs.modalComment.hide();
      this.$emit('updatePage');
    },
    createJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.job.id+'.json';
      var params = {job_id: this.job.id,message:this.comment};
      axios.post(url, params);
      this.updateJobCommentList();
      this.comment = '';
    },
    updateJobCommentList: function() {
      var url    = uri_base+'/rest/job/comment/'+this.job.id+'.json';
      var params = {job_id: this.job.id};
      var self = this;
      axios.get(url, params).then(function(response) {
        self.job.comments = response.data.comments;
      });
    },
  },
  template: ''
    + '<div class="card job_card">'
    + ' <div class="card-header alert" v-bind:class="job.state_class">'
    + '  <div class="row">'
    + '    <div class="col-md-6">'
    + '      <show-details @toggleDetails="toggleDetails()"></show-details>'
    + '      <span class="badge badge-secondary">{{ job.id }}</span> {{ job.name }} ({{ workerInfo.host }})</a>'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      {{ job.start_time_formatted }}'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      {{ job.duration }}'
    + '    </div>'
    + '    <div class="col-md-2">'
    + '      <!-- ACTIONS -->'
    + '      <console-log-link v-bind:loglink="workerInfo.loglink"></console-log-link>'
    + '      <job-details-link v-bind:id="job.id"></job-details-link>'
    + '      <comments-link v-show="show_comments" :job="job" ref="commentsLink"></comments-link>'
    + '      <job-retrigger-link v-show="is_admin" :id="job.id" :is_admin="is_admin"></job-retrigger-link>'
    + '      <pwrand-link v-show="show_pwrand" :job_id="job.id"></pwrand-link>'
    + '    </div>'
    + '  </div>'
    + ' </div>'
    + ' <task-list v-show="showDetails" ref="tasklist" v-bind:workerinfo="workerInfo" v-bind:subtasks="subtasks" v-bind:result="job.result"></task-list>'
    + ' <b-modal ref="modalComment" hide-footer :title="comment_title">'
    + '  <div>'
    + '   <single-job-comment v-for="cmt in job.comments" v-bind:key="cmt.id" v-bind:comment="cmt">'
    + '   </single-job-comment>'
    + '  </div>'
    + '  <div>'
    + '   New Comment:'
    + '   <textarea v-model="comment" rows="2" style="width: 100%"></textarea>'
    + '  </div>'
    + '  <div class="modal-footer">'
    + '   <button type="button" class="btn btn-success" v-on:click="createJobComment(job.id)">Add Comment</button>'
    + '   <button type="button" class="btn btn-secondary" v-on:click="closeModal()" aria-label="Close">Close</button>'
    + '  </div>'
    + ' </b-modal>'
    + ' <pwrand-modal v-bind:job="job" ref="modalPwRand"></pwrand-modal>'
    + '</div>'
});

Vue.component('comments-link',{
  methods: {
    showModal: function() {
      var p = this.$parent;
      p.showModal();
    }
  },
  props: ['job'],
  computed: {
    comments_length: function() {
      if (this.job.comments) {
        return this.job.comments.length;
      }
      return 0;
    }
  },
  template: ''
    + '<a class="float-right" style="margin-left:5px;" v-on:click="showModal()" data-bs-toggle="tooltip" data-bs-placement="top" title="Comments">'
    + '  <span v-if="comments_length > 0" key="commented"><i class="fas fa-comments"></i></span>'
    + '  <span v-else><i class="far fa-comments" key="uncommented"></i></span>'
    + '</a>'
});

Vue.component('job-details-link',{
  props: ['id'],
  template: ''
    + '<router-link class="float-right" style="margin-left:5px;" :to="\'/job_result/\'+id" data-bs-toggle="tooltip" data-bs-placement="top" title="Link to Result">'
    + '  <i class="fas fa-link"></i>'
    + '</router-link>'
});

Vue.component('job-retrigger-link',{
  props: ['id', 'is_admin'],
  methods: {
    retriggerJob: function() {
      var url  = uri_base + "/rest/job/retrigger/" + this.id + ".json";
      var self = this;
      axios.post(url, {is_admin: this.is_admin}).then(function(response) {
        show_messagebox(response.data.state, response.data.msg);
        var npage = self.$route.params.page;
        var o_job_states = ['running', 'failed', 'succeed', 'dispatching', 'triggered'];
        var o_query = { "job_states": o_job_states };
        if (! self.$route.query.show_only_latest_results ) {
          npage = 1;
          o_query['show_only_latest_results'] = true;
        }
        self.$router.push({
          name:   'job_history',
          params: {page: npage},
          query: o_query,
        });
      });
    },
  },
  template: ''
    + '<span class="float-right" style="margin-left:5px;" @click="retriggerJob()" data-bs-toggle="tooltip" data-bs-placement="top" title="Retrigger">'
    + '  <i class="fas fa-redo-alt"></i>'
    + '</span>'
});

Vue.component('pwrand-link',{
  props: ['job_id'],
  methods: {
    showModalPwRand: function() {
      var p0 = this.$parent;
      var r0 = p0.$refs.modalPwRand;
      var r1 = r0.$refs.modalPwRandModal;
      r1.show();
    },
  },
  template: ''
    + ' <a class="float-right" style="margin-left:5px;" v-on:click="showModalPwRand()" data-bs-toggle="tooltip" data-bs-placement="top" title="Password">'
    + '  <i class="fas fa-lock"></i>'
    + ' </a>'
});

Vue.component('console-log-link',{
  props: ['loglink'],
  template: ''
    + '<a class="float-right" style="margin-left:5px;" :href="loglink" target="_blank" data-bs-toggle="tooltip" data-bs-placement="top" title="Console Log">'
    + ' <i class="fa fa-file-alt"></i>'
    + '</a>'
});

Vue.component('pwrand-modal', {
  props: ['job'],
  template: ''
    + '<b-modal ref="modalPwRandModal" hide-footer title="Randomized Password">'
    + '<pre>'
    + 'gpg -d &lt;&lt;EOF |json_pp -f json -t dumper' + "\n"
    + '{{ job.pwrand }}'
    + "\n"
    + 'EOF'
    + '</pre>'
    + '</b-modal>'
});

Vue.component('single-job-comment', {
  props: ['comment'],
  methods: {
    editJobComment: function() {
      this.$refs.textarea_job_comment.readOnly = false;
      this.show_save = 1;
    },
    deleteJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.comment.id+'.json';
      var params = {comment_id: this.comment.id, };
      var self = this;
      var p = this.$parent;
      axios.delete(url, params).then(function(response) {
        p.$parent.updateJobCommentList();
      });
    },
    updateJobComment: function() {
      var url    = uri_base+'/rest/job/comment/'+this.comment.id+'.json';
      var params = {comment_id: this.comment.id, message: this.comment_message };
      var self = this;
      var p = this.$parent;
      axios.put(url, params).then(function(response) {
        p.$parent.updateJobCommentList();
      });
      this.$refs.textarea_job_comment.readOnly = true;
      this.show_save = 0;
    }
  },
  data: function() {
    return {
      show_mod: (user_name == this.comment.user.username) ? 1 : 0,
      show_save: 0,
      comment_message: this.comment.comment,
    }
  },
  template: ''
    + '<div class="panel panel-default">'
    + '  <div class="panel-heading">'
    + '    <div class=row>'
    + '      <div class=col-sm-9>'
    + '      {{ comment.user.username }} ({{comment.user.name}})'
    + '      </div>'
    + '      <div class="col-sm-3 text-right">'
    + '        <div v-show="show_mod">'
    + '          <button class="btn btn-primary" type="button" aria-label="Edit" v-on:click="editJobComment()">'
    + '            <i class="far fa-edit"></i>'
    + '          </button>'
    + '          <button class="btn btn-danger" type="button" aria-label="Delete" v-on:click="deleteJobComment()">'
    + '            <i class="far fa-trash-alt"></i>'
    + '          </button>'
    + '        </div>'
    + '      </div>'
    + '    </div>'
    + '   </div>'
    + '  <textarea v-model="comment_message" style="width:100%;margin-top:10px;margin-bottom:20px;" readonly ref="textarea_job_comment">'
    + '{{ comment.comment }}'
    + '</textarea>'
    + '   <button v-show="show_save" class="btn btn-success" v-on:click="updateJobComment()">Save</button>'
    + '</div>'
});

Vue.component('job-history-header', {
  template: ''
    + '    <div class="container-fluid">'
    + '     <div class="row alert alert-secondary">'
    + '      <div class="col-md-6">'
    + '       <span class="badge badge-secondary">ID</span>'
    + '       Job Name'
    + '      </div>'
    + '      <div class="col-md-2">Start Time</div>'
    + '      <div class="col-md-2">Duration</div>'
    + '      <div class="col-md-2 float-right">Actions</div>'
    + '     </div>'
    + '    </div>'
});

Vue.component('navigation-dropdown', {
  props: ['user_id', 'user_label', 'is_admin'],
  methods: {
    onLogin: function() {
      this.$emit('login');
    },
  },
  template: ''
    + '<ul class="navbar-nav ml-auto">'
    + ' <li class="nav-item active dropdown">'
    + '<a href="#"'
    + '  class="nav-link dropdown-toggle"'
    + '  data-toggle="dropdown"'
    + '  aria-haspopup="true"'
    + '  aria-expanded="false"'
    + '  id="navbarDropdown"'
    + ' >'
    + '  {{ user_label }}'
    + '</a>'
    + '  <div class="dropdown-menu dropdown-menu-right" aria-labelledby="navbarDropdown" style="padding:10px;">'
    + '  <div v-if="user_id">'
    + '   <router-link class="dropdown-item"   to="/settings" >Settings</router-link>'
    + '   <a class="dropdown-item" @click="$emit(\'logout\')">Logout</a>'
    + '   <div v-if="is_admin">'
    + '    <div class="dropdown-divider"></div>'
    + '     <router-link class="dropdown-item" to="/admin"   >Administration</router-link>'
    + '    </div>'
    + '   </div>'
    + '   <div v-else>'
    + '    <form @submit.prevent="onLogin">'
    + '      <input type=hidden name=return_url value="uri_base + request_path">'
    + '      <label for="username" class=sr-only>Login Name</label>'
    + '      <input style="margin-bottom: 5px" id="username" name=username class="form-control" placeholder="Login Name" required autofocus>'
    + '      <label for="password" class=sr-only>Password</label>'
    + '      <input style="margin-bottom: 5px;" type="password" name=password id="password" class="form-control" placeholder="Password" required>'
    + '      <input class="btn btn-success btn-block" type="submit" value="Sign in">'
    + '    </form>'
    + '    <hr/>'
    + '    <router-link class="btn btn-primary btn-block" to="/signup">Sign Up</router-link>'
    + '    <router-link class="dropdown-item"  to="/pwreset">Forgot password?</router-link>'
    + '   </div>'
    + '   <a class="dropdown-item" href="https://m0ses.github.io/kanku/" target=_blank>About Kanku</a>'
    + '   <a class="dropdown-item" href="https://github.com/M0ses/kanku" target=_blank>Code on github</a>'
    + '  </div>'
    + ' </li>'
    + '</ul>'
});

Vue.component('navigation', {
  props: ['active_roles', 'request_path', 'user_label', 'roles', 'user_id', 'is_admin'],
  data: function() {
    return {
      uri_base:   uri_base,
    };
  },
  methods: {
    logout: function() {
      var url  = uri_base + "/rest/logout.json";
      var self = this;
      var params = { kanku_notify_session : Cookies.get('kanku_notify_session') };
      axios.post(url, params).then(function(response) {
        if (response.data.authenticated == '0') {
          show_messagebox('success', "Logout succeed!");
        } else {
          show_messagebox('danger', "Logout failed!");
        }
        self.$emit("user-state-changed");
      })
      .catch(function (error) {
           console.log(error);
      });
    },
    login: function() {
      var req = {
        username: $('#username').val(),
        password: $('#password').val(),
      };
      var url = uri_base + "/rest/login.json";
      var self = this;
      var resp;
      axios.post(url, req).then(function(response) {
        resp = response.data;
        if (response.data.authenticated) {
          Cookies.set("kanku_notify_session", response.data.kanku_notify_session);
          show_messagebox('success', "Login succeed!");
        } else {
          show_messagebox('danger', "Login failed!");
        }
        self.$emit("user-state-changed");
      });
    },
  },
  template: ''
    + '    <nav class="navbar navbar-expand-lg navbar-light fixed-top bg-light" style="z-index:1040;">'
    + '     <div class="container">'
    + '        <div class="navbar-header">'
    + '           <router-link to="/" class="navbar-brand">Kanku</router-link>'
    + '        </div>'
    + '        <div id="navbarSupportedContent" class="collapse navbar-collapse">'
    + '          <ul class="navbar-nav">'
    + '            <li class="nav-item active">                                    <router-link class="nav-link" to="/job_history/1" >Job History</router-link></li>'
    + '            <li class="nav-item active">                                    <router-link class="nav-link" to="/guest"       >Guest</router-link></li>'
    + '            <li class="nav-item active">                                    <router-link class="nav-link" to="/worker"      >Worker</router-link></li>'
    + '            <li v-if="(active_roles.User || active_roles.Admin)" class="nav-item active"> <router-link class="nav-link" to="/job/1"         >Job</router-link></li>'
    + '            <li v-if="(active_roles.Admin)" class="nav-item active"> <router-link class="nav-link" to="/job_group/1"   >Job Group</router-link></li>'
    + '            <li v-if="roles.length > 0" class="nav-item active">            <router-link class="nav-link" to="/notify"      >Notify</router-link></li>'
    + '          </ul>'
    + '          <admin-switch v-if="active_roles.Admin" @changed-is-admin="$emit(\'changed-is-admin\')"></admin-switch>'
    + '          <navigation-dropdown :user_id="user_id" :is_admin="is_admin" :user_label="user_label" @logout="logout" @login="login"></navigation-dropdown>'
    + '        </div>'
    + '     </div>'
    + '    </nav>'
});

Vue.component('admin-switch', {
  props: ['active_roles'],
  data: function () {
    return {
      is_admin: this.$route.query.is_admin || false,
    };
  },
  template: ''
    + '<div class="custom-control custom-switch float-left">'
    + '  <input @change="$emit(\'changed-is-admin\')" v-model="is_admin" type="checkbox" class="custom-control-input" id="adminSwitch">'
    + '  <label class="custom-control-label" for="adminSwitch">Admin</label>'
    + '</div>'
});

Vue.component('search-field',{
  props: ['comment'],
  data: function() {
    return {
      filter: this.$route.query.filter
    };
  },
  methods: {
    updateSearch: function() {
      if (this.$parent.filter == this.filter) {
        return;
      }
      this.$parent.filter = this.filter;
      var currQ = this.$route.query;
      var newQ  = {...currQ, filter: this.filter};
      this.$router.push({ path: this.$router.currentPath, params: this.$route.params, query: newQ});
      this.$emit('search-term-change');
    },
    clearSearch: function() {
      if (this.filter == undefined) {
        return;
      }
      this.$parent.filter = this.filter = undefined;
      var currQ = {...this.$route.query};
      delete currQ['filter'];
      this.$router.push({ query: currQ});
      this.$emit('search-term-change');
    }
  },
  template: ''
    + '    <div class="btn-group col-md-4">'
    + '      <input type="text" v-model="filter" @keyup.enter="updateSearch" class="form-control" :placeholder="comment">'
    + '      <span @click="clearSearch()" style="margin-left:-20px;margin-top:10px;">'
    + '          <i class="far fa-times-circle"></i>'
    + '       </span>'
    + '    </div>'
});

Vue.component('paginator', {
  props: ['page', 'is_admin', 'total_pages'],
  methods: {
    nextpage: function() {
      this.$parent.page++;
      router.push({ params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updatePage');
    },
    prevpage: function() {
      this.$parent.page--;
      router.push({ params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updatePage');
    },
    firstpage: function() {
      this.$parent.page = 1;
      router.push({ params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updatePage');
    },
    lastpage: function() {
      this.$parent.page = this.total_pages;
      router.push({ params: { page: this.$parent.page}, query: this.$route.query});
      this.$emit('updatePage');
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

Vue.component('limit-select',{
  data: function() {
    return {limit:10}
  },
  methods: {
    setNewLimit: function() {
      this.$parent.limit = this.limit;
      this.$emit('updatePage');
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

const pageNotFound = {
  template: '<head-line text="404 - Page not found"></head-line>'
};
