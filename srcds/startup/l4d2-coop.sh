#!/bin/bash

HOSTIP=external_ip
LANIP=internal_ip
HOSTPORT=28005
CLIENTPORT=28006

export RDTSC_FREQUENCY=3400.000000

screen -dmS L4D2 ./srcds_run -autoupdate -steam_dir /home/srcds -steamcmd_script l4d2_upd.txt -nowatchdog +ip $LANIP +hostip $HOSTIP +hostport $HOSTPORT +clientport $CLIENTPORT +map c1m1_hotel +mp_gamemode coop

unset RDTSC_FREQUENCY
