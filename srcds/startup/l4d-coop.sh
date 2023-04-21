#!/bin/bash

HOSTIP=external_ip
LANIP=internal_ip
HOSTPORT=8000
CLIENTPORT=8001

export RDTSC_FREQUENCY=disabled

screen ./srcds_run -console -autoupdate -secure -game left4dead +hostip $HOSTIP +ip $LANIP +hostport $HOSTPORT +clientport $CLIENTPORT +mp_gamemode coop +sv_lan 0 +map l4d_hospital01_apartment

unset RDTSC_FREQUENCY
