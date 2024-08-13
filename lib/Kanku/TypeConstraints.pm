package Kanku::TypeConstraints;

use strict;
use warnings;

use Moose::Util::TypeConstraints;

subtype 'URL',
  as 'Str',
  where { m{(https?|socket|file|wss?)://([^:]+(:[^@]+)?@)?([^/]+)}smx; },
  message { "Invalid URL '$_'!" };

subtype 'ExistantFile',
  as 'Str',
  where { -f $_; },
  message { "File '$_' doesn't exist!" };

enum 'LogLevel' => [qw/FATAL ERROR WARN INFO DEBUG TRACE/];

enum 'OutputFormat' => [qw/json dumper yaml none pjson/];

enum 'KeyringBackend' => [qw/KDEWallet Gnome Memory None/];

enum 'ImageType' => [qw/kanku vagrant/];

enum 'DomainAction' => [qw[reboot shutdown create destroy undefine]];

1;
