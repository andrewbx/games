#!/bin/bash

HOSTIP=external_ip
LANIP=internal_ip
HOSTPORT=28000
CLIENTPORT=28001

export RDTSC_FREQUENCY=3400.000000

screen -dmS GMOD ./srcds_run -autoupdate -steam_dir /home/srcds -steamcmd_script update_gmod.txt -nowatchdog +ip $HOSTIP +hostip $HOSTIP +hostport $HOSTPORT +clientport $CLIENTPORT -game garrysmod +maxplayers 8 +map gm_flatgrass

unset RDTSC_FREQUENCY
