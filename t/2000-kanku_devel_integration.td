#!/usr/bin/bash

[ -d /tmp/prj ] || mkdir -p /tmp/prj
TDIR=`mktemp -d -p /tmp/prj`
LOG=/tmp/kanku-up.log

echo -n > $LOG

[ -f $HOME/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4086 -N '' -f $HOME/.ssh/id_rsa
cp /tmp/kanku/KankuFile.examples/KankuFile.simple $TDIR/KankuFile
set -e
kanku help
eval `ssh-agent`
ssh-add
cd $TDIR

KOPTS="--ll TRACE"
tests=0

function test_kanku_cli {
  test=$(($test+1))
  not=''
  kanku $@ $KOPTS 2>&1 >> $LOG
  [ $? -gt 0 ] && not=not
  echo $not"ok $test - Checking '$@'" |tee -a $LOG
  return 0
}

echo "1..6"

test_kanku_cli destroy
test_kanku_cli up
test_kanku_cli ip
test_kanku_cli status
test_kanku_cli ssh -u root -e /bin/true
test_kanku_cli destroy

exit 0
