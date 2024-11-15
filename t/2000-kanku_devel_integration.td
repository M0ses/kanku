#!/usr/bin/bash

[ -d /tmp/prj ] || mkdir -p /tmp/prj
TDIR=`mktemp -d -p /tmp/prj`
LOG=/tmp/kanku-up.log
BASEDIR=`dirname $0`

echo -n > $LOG

[ -f $HOME/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4086 -N '' -f $HOME/.ssh/id_rsa
cp $BASEDIR/fixtures/KankuFile $TDIR/KankuFile
chmod 777 $TDIR
cd $TDIR
eval `ssh-agent`
ssh-add

KOPTS="--ll TRACE"
tests=0

function test_kanku_cli {
  test=$(($test+1))
  not=''
  cmd="kanku $@ $KOPTS"
  [ -n "$TEST_VERBOSE" ] && echo "COMMAND: >>$cmd<<" >&2
  $cmd 2>&1 >> $LOG
  [ $? -gt 0 ] && not=not
  echo $not"ok $test - Checking '$@'" |tee -a $LOG
  return 0
}

echo "1..7"

test_kanku_cli help
test_kanku_cli destroy
test_kanku_cli up
test_kanku_cli ip
test_kanku_cli status
test_kanku_cli ssh -u root -e /bin/true
test_kanku_cli destroy

exit 0
