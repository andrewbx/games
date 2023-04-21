#!/bin/sh

# Start DeathMatch

screen ./ucc server \
DM-Knotra?Game=RuneI.RuneMultiPlayer?mutator=\
RuneI.MutatorNoRunes,\
ClientCamera.ClientCamera,\
Spear.MutatorCelticSpear,\
iShowNames.ShowNames,\
CrittersWeaponsV2.CrittersMutator,\
SirMutPack12.SirsOfCamelot10,\
iMOTDv3.MOTDInit,\
DLSeekerV5.DLSeeker,\
RegenAfterKill.RegenAfterKill,\
?Listen -ini=Rune-DM.ini -server -lanplay log=dm-server.log

#-EOF
