#!/bin/bash

HOSTIP=external_ip
LANIP=internal_ip
HOSTPORT=28000
CLIENTPORT=28001

export RDTSC_FREQUENCY=3400.000000

screen ./srcds_run -autoupdate -noassert -nobreakpad -nominidump -nowatchdog +hostip $HOSTIP +ip $LANIP +hostport $HOSTPORT +clientport $CLIENTPORT +sv_lan 0 +map l4d_vs_smalltown01_caves

unset RDTSC_FREQUENCY
