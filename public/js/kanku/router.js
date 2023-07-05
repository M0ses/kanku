const routes = [
  { path: '*'                    , component: pageNotFound   },
  { path: '/'                    , component: indexPage      },
  { path: '/admin'               , component: adminPage      },
  { path: '/guest/:domain_name?' , component: guestPage      },
  { path: '/worker'              , component: workerPage     },
  { path: '/notify'              , component: notifyPage     },
  { path: '/settings'            , component: settingsPage   },
  { path: '/job_result/:job_id'  , component: jobResultPage  },
  { path: '/pwreset'             , component: pwResetPage    },
  { path: '/signup'              , component: signUpPage     },
  { path: '/login'               , component: pwSetPage      },
  { path: '/signin'  , component: signInForm     },
  { name: 'job'        , path: '/job/:page'         , component: jobPage        },
  { name: 'job_history', path: '/job_history/:page' , component: jobHistoryPage },
  { name: 'job_group'  , path: '/job_group/:page'   , component: jobGroupPage   },
];

const router = new VueRouter({
  routes // short for `routes: routes`
});

var app = new Vue({
  el: '#vue_app',
  router,
  props: ['sock'],
  data: {
    logged_in_user: logged_in_user,
    request_path:   request_path,
    uri_base:       uri_base,
    is_admin:       false,
  },
  computed: {
    user_label: function() { return (this.logged_in_user && this.logged_in_user.name) ? this.logged_in_user.name : 'Sign In' },
    roles: function() { 
      var r = [];
      var liu = this.logged_in_user;
      if (liu == undefined) {
        return r;
      }
      if (liu.role_id == undefined) {
        return r;
      }
      $.each(Object.keys(liu.role_id), function(idx, key){
        if (liu.role_id[key]){ r.push(key); }
      });
      return r;
    },
    active_roles: function() {
      var r = {};
      var liu = this.logged_in_user;
      if (liu == undefined) {
        return r;
      }
      if (liu.role_id == undefined) {
        return r;
      }
      $.each(Object.keys(liu.role_id), function(idx, key){
        r[key] = liu.role_id[key];
      });
      return r;
    },
    user_id: function() {
      if (this.logged_in_user) { return this.logged_in_user.id };
      return 0;
    },
    show_comments: function() {
      var liu = this.logged_in_user;
      var  sc = false;
      if (liu == undefined) {
        return false;
      }
      if (liu.role_id == undefined) {
        return false;
      }
      $.each(Object.keys(liu.role_id), function(idx, key){
        if (key == 'Admin' && liu.role_id[key] == '1') { sc = true }
        if (key == 'User' && liu.role_id[key] == '1')  {  sc = true }
      });
      return sc;
    },
  },
  methods: {
    refreshUserInfo: function() {
      var url = uri_base + "/rest/userinfo.json";
      var self = this;
      axios.get(url).then(function(response) {
        self.logged_in_user = response.data.logged_in_user;
        if (self.logged_in_user.id) {
          self.sock = startWSConnection(self.logged_in_user.id);
        }
      });;
    },
    toogleIsAdmin: function() {
       this.is_admin = !this.is_admin;
       var q2 = this.$route.query || {};
       var q  = {...q2};
       if (this.is_admin) {
         q['is_admin'] = true;
       } else {
         delete q['is_admin'];
       }
       this.$router.push({query: q});
    },
  },
  created: function() {
     $(window).scroll(function () {
	if ($(this).scrollTop() > 50) {
	    $('#back-to-top').show();
	} else {
	    $('#back-to-top').hide();
	    $('#back-to-top').tooltip('hide');
	}
    });
    if (this.$route.query) {
      this.is_admin = this.$route.query.is_admin || false;
    }
  },
  template: ''
    + '<div>'
    + ' <navigation :user_id="user_id" :user_label="user_label" :roles="roles" :active_roles="active_roles" :request_path="request_path" :is_admin="is_admin" @user-state-changed="refreshUserInfo" @changed-is-admin="toogleIsAdmin"></navigation>'
    + ' <message-box-placeholder></message-box-placeholder>'
    + ' <div id="content" class="container">'
    + ' <router-view :user_id="user_id" :is_admin="is_admin" :show_comments="show_comments" @user-state-changed="refreshUserInfo"></router-view>'
    + ' <!-- content goes here -->'
    + ' <to-top-button></to-top-button>'
    + ' </div>'
    + '</div>'
});
