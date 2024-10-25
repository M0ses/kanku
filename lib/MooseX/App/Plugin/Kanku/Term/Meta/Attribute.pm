# ============================================================================
package MooseX::App::Plugin::Kanku::Term::Meta::Attribute;
# ============================================================================

use utf8;
use 5.010;

use namespace::autoclean;
use Moose::Role;
use Moose::Util::TypeConstraints;

use List::Util qw(first);
use Term::ReadKey;

subtype 'Password',
  as 'Str',
  where { length > 0 },
  message { 'Empty password is not allowed!' };


has 'cmd_term' => (
    is          => 'ro',
    isa         => 'Bool',
    default     => sub {0},
);

has 'cmd_term_label' => (
    is          => 'ro',
    isa         => 'Str',
    predicate   => 'has_cmd_term_label',
);

has 'cmd_term_input_hidden' => (
    is          => 'ro',
    isa         => 'Bool',
    default     => sub {0},
);

sub cmd_term_label_full {
    my ($self) = @_;

    my $label = $self->cmd_term_label_name;
    my @tags;
    if ($self->is_required) {
        push(@tags,'Required');
    } else {
        push(@tags,'Optional');
    }

    if ($self->has_type_constraint) {
        my $type_constraint = $self->type_constraint;
        if ($type_constraint->is_a_type_of('Bool')) {
            push(@tags,'Y/N');
	} elsif ($self->cmd_term_input_hidden) {
            push(@tags,'Hidden input');
        } else {
            push(@tags,$self->cmd_type_constraint_description($type_constraint));
        }
    }
    if (scalar @tags) {
        $label .= ' ('.join(', ',@tags).')';
    }

    return $label;
}

sub cmd_term_label_name {
    my ($self) = @_;

    my $label;
    if ($self->has_cmd_term_label) {
        return $self->cmd_term_label;
    } elsif ($self->has_documentation) {
        return $self->documentation;
    } else {
        return $self->name;
    }
}



sub cmd_term_read {
    my ($self) = @_;

    if ($self->has_type_constraint
        && $self->type_constraint->is_a_type_of('Bool')) {
        return $self->cmd_term_read_bool();
    } elsif ($self->has_type_constraint
        && $self->type_constraint->isa('Moose::Meta::TypeConstraint::Enum')) {
        return $self->cmd_term_read_enum();
    } else {
        return $self->cmd_term_read_string();
    }
}

sub cmd_term_read_string {
    my ($self) = @_;

    my $label = $self->cmd_term_label_full;
    my ($return,@history,$history_disable,$allowed);

    binmode STDIN,':encoding(UTF-8)';

    # Prefill history with enums
    if ($self->has_type_constraint) {
        my $type_constraint = $self->type_constraint;
        if ($type_constraint->isa('Moose::Meta::TypeConstraint::Enum')) {
            push(@history,@{$self->type_constraint->values});
            $history_disable = 1
        } elsif (!$type_constraint->has_coercion) {
            if ($type_constraint->is_a_type_of('Int')) {
                $allowed = qr/[0-9]/;
            } elsif ($type_constraint->is_a_type_of('Num')) {
                $allowed = qr/[0-9.]/;
            }
        }
    }

    $history_disable = 1 if $self->cmd_term_input_hidden;

    push(@history,"")
        unless scalar @history;

    my $history_index = 0;
    my $history_add = sub {
        my $entry = shift;
        if (! $history_disable
            && defined $entry
            && $entry !~ m/^\s*$/
            && ! first { $entry eq $_ } @history) {
            push(@history,$entry);
        }
    };

    ReadMode('cbreak'); # change input mode
    TRY_STRING:
    while (1) {
        print "\n"
            if defined $return
            && $return !~ /^\s*$/;
        $return = '';

	$self->_print_label;

        1 while defined ReadKey -1; # discard any previous input

        my $cursor = 0;

        KEY_STRING:
        while (1) {
            my $key         = ReadKey 0; # read a single character
            my $length      = length($return);
            my $key_code    = ord($key);

            if ($key_code == 10) { # Enter
                print "\n";
                my $error;
                if ($return =~ m/^\s*$/) {
                    if ($self->is_required) {
                        $error = 'Value is required';
                    } else {
                        $return = undef;
                        last TRY_STRING;
                    }
                } else {
                    $error = $self->cmd_type_constraint_check($return);
                }
                if ($error) {
		    $self->_headline($error);
                    $history_add->($return);
                    next TRY_STRING;
                } else {
                    last TRY_STRING;
                }
            } elsif ($key_code == 27) { # Escape sequence
		#
		# Do not accecpt cursor movement on hidden input
		# as this is mostly used for password/pin and its uncommon
		# to enable cursor function there
		#
                my $escape;

                while (1) { # Read rest of escape sequence
                    my $code = ReadKey -1;
                    last unless defined $code;
                    $escape .= $code;
                }

		# Skipping if input is hidden. This needs to be done
		# after reading the rest of the escape seqence.
		next if $self->cmd_term_input_hidden;

                if (defined $escape) {
                    if ($escape eq '[D') { # Cursor left
                        if ($cursor > 0) {
                            print "\b";
                            $cursor--;
                        }
                    }
                    elsif ($escape eq '[C') { # Cursor right
                        if ($cursor < length($return)) {
                            print substr $return,$cursor,1;
                            $cursor++;
                        }
                    }
                    elsif ($escape eq '[A') { # Cursor up
                        $history_add->($return);
                        print "\b" x $cursor;
                        print " " x length($return);
                        print "\b" x length($return);

                        $history_index ++
                            if defined $history[$history_index]
                            && $history[$history_index] eq $return;
                        $history_index = 0
                            unless defined $history[$history_index];

                        $return = $history[$history_index];
                        $cursor = length($return);
                        print $return;
                        $history_index++;
                    }
                    elsif ($escape eq '[3~') { # Del
                        if ($cursor != length($return)) {
                            substr $return,$cursor,1,'';
                            print substr $return,$cursor;
                            print " ".(("\b") x (length($return) - $cursor + 1));
                        }
                    }
                    elsif ($escape eq 'OH') { # Pos 1
                        print (("\b") x $cursor);
                        $cursor = 0;
                    }
                    elsif ($escape eq 'OF') { # End
                        print substr $return,$cursor;
                        $cursor = length($return);
                    }
                    #else {
                    #    print $escape;
                    #}
                } else {
                    $history_add->($return);
                    next TRY_STRING;
                }

            } elsif ($key_code == 127) { # Backspace
                if ($cursor == 0) { # Ignore first
                    next KEY_STRING;
                }
                $cursor--;
                substr $return,$cursor,1,''; # string
                print "\b".substr $return,$cursor; # print
                print " ".(("\b") x (length($return) - $cursor + 1)); # cursor
            } else { # Character
                if ($key_code <= 31) { # ignore controll chars
                    print "\a";
                    next KEY_STRING;
                } elsif (defined $allowed
                    && $key !~ /$allowed/) {
                    print "\a";
                    next KEY_STRING;
                }
                substr $return,$cursor,0,$key; # string
		if ($self->cmd_term_input_hidden) {
		  print '*';
		} else {
                  print substr $return,$cursor; # print
		}
                $cursor++;
                print (("\b") x (length($return) - $cursor)); # cursor
            }
        }
    }
    ReadMode 0;

    return $return;
}

sub cmd_term_read_bool {
    my ($self) = @_;

    my $return;

    $self->_print_label;
    ReadMode 4; # change to raw input mode
    TRY:
    while (1) {
        1 while defined ReadKey -1; # discard any previous input
        my $key = ReadKey 0; # read a single character
        if ($key =~ /^[yn]$/i) {
            say uc($key);
            $return = uc($key) eq 'Y' ? 1:0;
            last;
        } elsif ((ord($key) == 10 || ord($key) == 27) && ! $self->is_required) {
            last;
        } elsif (ord($key) == 3) {
            ReadMode 0;
            kill INT => $$; # Not sure ?
        }
    }
    ReadMode 0;

    return $return;
}

sub cmd_term_read_password {
    my ($self) = @_;

    $self->_print_label;

    my $return;
    ReadMode 4; # change to raw input mode
    TRY:
    while (1) {
      1 while ReadKey -1;
        my $key         = ReadKey 0; # read a single character
        my $length      = length($return);
        my $key_code    = ord($key);

        if ($key_code == 10) { # Enter
        
	  if ( length($return) < 1) {
	    say 'Password to short! Please retry.';
	  } else {
            last;
	  }
	} else {
	  $return .= $key;
	}
    }
    ReadMode 0;

    return $return;
}

sub cmd_term_read_enum {
    my ($self) = @_;

    $self->_print_label;
    my $num_max = $self->_print_selection;

    my $return;
    ReadMode 1; # change to raw input mode
    print "\es";
    while (1) {
      1 while ReadLine -1;
        my $select = ReadLine 0;
	chomp $select;
	if ( $select !~ /^[0-9]+$/smx) {
	  print "\e2Invalid input! '$select' is not a number.";
	} elsif ($select > $num_max) {
	  print "\e2Invalid input! '$select' is out of range (0-$num_max).";
	} else {
	  $return = $self->type_constraint->values->[$select];
          $self->type_constraint->constraint->($return);
          last if $self->type_constraint->constraint->($return);;
	  print "\e2Invalid input! Unknown error for input '$select'.";
	}
	print "\eM\e[2K\r";
    }
    ReadMode 0;

    return $return
}

sub _print_label {
    my ($self) = @_;
    $self->_headline($self->cmd_term_label_full);
}

sub _headline {
    my ($self, $text) = @_;
    if (defined $Term::ANSIColor::VERSION) {
        say Term::ANSIColor::color('white bold').$text.' :'.Term::ANSIColor::color('reset');
    } else {
        say $text.": ";
    }
}

sub _print_selection {
    my ($self) = @_;
    my $csel=0;
    say '';
    for my $val (@{$self->type_constraint->values}) {
      say "[$csel] - $val";
      $csel++;
    }
    say '';
    $self->_headline("Enter number");
    return $csel-1;
}

around 'cmd_tags_list' => sub {
    my $orig = shift;
    my ($self) = @_;

    my @tags = $self->$orig();

    push(@tags,'Kanku::Term')
        if $self->can('cmd_term')
        && $self->cmd_term;

    return @tags;
};

{
    package Moose::Meta::Attribute::Custom::Trait::AppTerm;

    use strict;
    use warnings;

    sub register_implementation { return 'MooseX::App::Plugin::Kanku::Term::Meta::Attribute' }
}

1;
