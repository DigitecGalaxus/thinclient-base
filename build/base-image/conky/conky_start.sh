#!/bin/sh

killall conky
/usr/bin/conky -d
sleep 5
killall -SIGUSR1 conky
