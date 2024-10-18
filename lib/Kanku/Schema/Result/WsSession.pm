package Kanku::Schema::Result::WsSession;
use base qw/DBIx::Class::Core/;
__PACKAGE__->table('ws_session');
__PACKAGE__->add_columns(
    session_token => { data_type => 'varchar', size => 32 },
    user_id       => { data_type => 'integer' },
    # session states:
    # =  0  - initiated
    # >  0 - permission level (authenticated)
    # = -1  - authentication failed
    # = -2  - connection closed
    permissions   => { data_type => 'integer' },
    filters       => { data_type => 'text' },
);
__PACKAGE__->set_primary_key('session_token');

1;
