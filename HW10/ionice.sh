#!/bin/bash

trap 'trap " " SIGTERM; kill 0; wait' SIGINT SIGTERM

rm -f /tmp/ioniceHiPri.tmp /tmp/ioniceLowPri.tmp
cp /dev/null /tmp/ionice.log

lowPriority()
{
  echo "$(date) - Start dd with low IO priority." >> /tmp/ionice.log
  ionice -c2 -n7 dd if=/dev/random of=/tmp/ioniceLowPri.tmp bs=64M count=2 oflag=dsync > /dev/null 2>&1
  echo "$(date) - Stop dd with low IO priority." >> /tmp/ionice.log
}

hiPriority() {
  echo "$(date) - Start dd with hi IO priority." >> /tmp/ionice.log
  ionice -c2 -n0 dd if=/dev/random of=/tmp/ioniceHiPri.tmp bs=64M count=2 oflag=dsync > /dev/null 2>&1
  echo "$(date) - Stop dd with hi IO priority." >> /tmp/ionice.log
}

lowPriority &
hiPriority &

wait

cat /tmp/ionice.log
