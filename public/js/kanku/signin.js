const signInForm = {
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
        username: $('#username1').val(),
        password: $('#password1').val(),
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
      if (this.$route.query.return_url) {
        router.push({path: this.$route.query.return_url});
        this.$emit('updatePage');
      }
    },
  },
  template: ''
    + '<signin_form @login="login" :form_id=1></signin_form>'
};
