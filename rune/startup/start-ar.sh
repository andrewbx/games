#!/bin/sh

# Start ArenaMatch

screen ./ucc server \
AR-Champions?Game=Arena.ArenaGameInfo?mutator=\
iShowNames.ShowNames,\
CrittersWeaponsV2.CrittersMutator,\
SirMutPack12.SirsOfCamelot10,\
iMOTDv3.MOTDInit,\
DLSeekerV5.DLSeeker\
?Listen -ini=Rune-AR.ini -lanplay -server -nolog

#-EOF
