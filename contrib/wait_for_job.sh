#!/bin/bash


RUNNING=1

while [ $RUNNING -gt 0 ];do
  RUNNING=$(kanku rhistory list --state running --state dispatching --ll FATAL --format json|json_xs -e 'print $_->{total_entries};' -t none)
  sleep 1
done

SUCCEED=$(kanku rhistory list --state succeed --ll FATAL --format json|json_xs -e 'print $_->{total_entries};' -t none)

[ $SUCCEED -gt 0 ] && exit 0

exit 1
