/**
* L4D Force Mission Changer
* For Sourcemod 1.2.0
* THX! DDR Khat
*
* Version 1.3.2: 
*				Fix mission announce bug
*				Add cvar sm_l4d_fmc_dbug write event log to file
*				Add cvar sm_l4d_fmc_re_timer_block block double event round_end
* Version 1.3.1: Ready for L4D version 1.0.1.2
*/

#pragma semicolon 1
#include <sourcemod>
#define Version "0.2.0"

#define MISSION_ROTATIONS 0
#define DEFAULT_GAMEMODE    "versus"
#define DEFAULT_MAP         "l4d_vs_smalltown01_caves"

new Handle:cvarAnnounce = INVALID_HANDLE;
new Handle:Allowed = INVALID_HANDLE;
new Handle:AllowedDie = INVALID_HANDLE;
new Handle:DefM;
new Handle:CheckRoundCounter;
new Handle:ChDelayVS;
new Handle:ChDelayCOOP;
new Handle:TimerRoundEndBlockVS;

new Handle:hKVSettings = INVALID_HANDLE;

new String:FMC_FileSettings[128];
new String:current_map[64];
new String:announce_map[64];
new String:next_mission_def[64];
new String:next_mission_force[64] = "none";
new RoundEndCounter = 0;
new RoundEndBlock = 0;
new bool:g_bDefMapLoaded = false;
new bool:g_bAllBotsTeam = false;
new bool:g_bRoundStart = false;

public Plugin:myinfo =
{
	name = "Map Changer",
	author = "XBetaAlpha",
	description = "Force change to next campaign.",
	version = Version,
	url = ""
};

public OnPluginStart()
{
	decl String:ModName[50];
	GetGameFolderName(ModName, sizeof(ModName));

	if(!StrEqual(ModName, "left4dead", false))
		SetFailState("Use this Left 4 Dead only.");

	hKVSettings=CreateKeyValues("ForceMissionChangerSettings");
  	BuildPath(Path_SM, FMC_FileSettings, 128, "data/l4d_mapchanger.txt");
	if(!FileToKeyValues(hKVSettings, FMC_FileSettings))
		SetFailState("Force Mission Changer settings not found!");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_FinalWin);
	HookEvent("mission_lost", Event_FinalLost);
	HookEvent("round_start", Event_RoundStart);

	CreateConVar("sm_l4d_fmc_version", Version, "Version of L4D Force Mission Changer plugin.", FCVAR_PLUGIN|FCVAR_DONTRECORD);

	Allowed = CreateConVar("sm_l4d_fmc", "1", "Enables Force changelevel when mission end.");
	AllowedDie = CreateConVar("sm_l4d_fmc_ifdie", "1", "Enables Force changelevel when all player die on final map in coop gamemode.");
	DefM = CreateConVar("sm_l4d_fmc_def", "c1m1_hotel", "Mission for change by default.");
	CheckRoundCounter = CreateConVar("sm_l4d_fmc_crec", "4", "Quantity of events RoundEnd before force of changelevel in versus: 4 for l4d <> 1.0.1.2");
	ChDelayVS = CreateConVar("sm_l4d_fmc_chdelayvs", "0.0", "Delay before versus mission change (float in sec).");
	ChDelayCOOP = CreateConVar("sm_l4d_fmc_chdelaycoop", "0.0", "Delay before coop mission change (float in sec).");
	TimerRoundEndBlockVS = CreateConVar("sm_l4d_fmc_re_timer_block", "0.5", "Time in which current event round_end is not considered (float in sec).");
	cvarAnnounce = CreateConVar("sm_l4d_fmc_announce", "1", "Enables next mission to advertise to players.");

	AutoExecConfig(true, "l4d_mapchanger");

	Sub_ChangeToDefaultMap();
}

public OnMapStart()
{
	RoundEndCounter = 0;
	RoundEndBlock = 0;

	decl String:GameMode[50];
	GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode));

	if (StrContains(GameMode, DEFAULT_GAMEMODE) == -1)
		ServerCommand("map %s %s", DEFAULT_MAP, DEFAULT_GAMEMODE);

	if(GetConVarInt(Allowed) == 1)
	{
		next_mission_force = "none";
		GetCurrentMap(current_map, 64);
		GetConVarString(DefM, next_mission_def, 64);

		if (StrContains(current_map, "_hospital0") != -1)
			SetConVarInt(CheckRoundCounter, 4);
		else if (StrContains(current_map, "_smalltown0") != -1)
			SetConVarInt(CheckRoundCounter, 4);
                else if (StrContains(current_map, "_farm0") != -1)
                        SetConVarInt(CheckRoundCounter, 4);
                else if (StrContains(current_map, "_airport0") != -1)
                        SetConVarInt(CheckRoundCounter, 4);
                else if (StrContains(current_map, "_garage0") != -1)
                        SetConVarInt(CheckRoundCounter, 1);
		else if (StrContains(current_map, "_river0") != -1)
			SetConVarInt(CheckRoundCounter, 2);

		else
			SetConVarInt(CheckRoundCounter, 4);

		KvRewind(hKVSettings);
		if(KvJumpToKey(hKVSettings, current_map))
			KvGetString(hKVSettings, "next mission map", next_mission_force, 64, next_mission_def);

		if (StrEqual(next_mission_force, "none") != true)
		{
			if (!IsMapValid(next_mission_force))
				next_mission_force = next_mission_def;
		}

		KvRewind(hKVSettings);
	}
}

public OnPluginEnd()
{
        g_bDefMapLoaded = false;
}

public OnClientPutInServer(client)
{
	if(client && !IsFakeClient(client) && GetConVarBool(cvarAnnounce))
		CreateTimer(20.0, TimerAnnounce, client);
}

public bool:OnClientConnect(client, String: rejectmsg[], maxlen)
{
        if(client && !IsFakeClient(client))
        {
                if (!g_bAllBotsTeam)
                {
                        SetConVarInt(FindConVar("sb_all_bot_team"), 1);
			//SetConVarInt(FindConVar("allow_all_bot_survivor_team"), 1);
                        g_bAllBotsTeam = true;
                }
        }

        return true;
}

public OnClientDisconnect(client)
{
	if (IsFakeClient(client))
		return;

	if (g_bRoundStart && !Sub_HumansInGame(client))
		CreateTimer(15.0, Timer_CheckEmptyServer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckEmptyServer(Handle:hTimer)
{
	if (g_bRoundStart && !Sub_HumansInGame(0))
	{
	        LogMessage("[+] Empty Server Detected: Resetting Server.");
        	Sub_ResetServerFull("Server empty.");
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundStart = true;
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundStart = false;

	if (RoundEndBlock == 0)
	{
		RoundEndCounter += 1;
		RoundEndBlock = 1;
		CreateTimer(GetConVarFloat(TimerRoundEndBlockVS), TimerRoundEndBlock);
	}

	if(GetConVarInt(Allowed) == 1 && l4d_gamemode() == 2 && StrEqual(next_mission_force, "none") != true && GetConVarInt(CheckRoundCounter) != 0 && RoundEndCounter >= GetConVarInt(CheckRoundCounter))
	{
		CreateTimer(GetConVarFloat(ChDelayVS), TimerChDelayVS);
		RoundEndCounter = 0;
	}
}

public Action:Event_FinalWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(Allowed) == 1 && l4d_gamemode() == 1 && StrEqual(next_mission_force, "none") != true)
		CreateTimer(GetConVarFloat(ChDelayCOOP), TimerChDelayCOOP);
}

public Action:Event_FinalLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(Allowed) == 1 && GetConVarInt(AllowedDie) && l4d_gamemode() == 1 && StrEqual(next_mission_force, "none") != true)
		CreateTimer(GetConVarFloat(ChDelayCOOP), TimerChDelayCOOP);
}

public Action:TimerAnnounce(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		GetCurrentMap(current_map, 64);

		if (StrContains(current_map, "_airport0") != -1)
			announce_map = "Dead Air";
		else if (StrContains(current_map, "_farm0") != -1)
			announce_map = "Blood Harvest";
		else if (StrContains(current_map, "_hospital0") != -1)
			announce_map = "No Mercy";
		else if (StrContains(current_map, "_smalltown0") != -1)
			announce_map = "Death Toll";
                else if (StrContains(current_map, "_garage0") != -1)
                        announce_map = "Crash Course";
		else if (StrContains(current_map, "sv_lighthouse") != -1)
                        announce_map = "Light House";
                else if (StrContains(current_map, "deathaboard") != -1)
                        announce_map = "Death Aboard";
                else if (StrContains(current_map, "deathpull") != -1)
                        announce_map = "Death Pull";
                else if (StrContains(current_map, "l4d_nt0") != -1)
                        announce_map = "Night Terror";
                else if (StrContains(current_map, "deadcity") != -1)
                        announce_map = "Dead City";
                else if (StrContains(current_map, "c1m") != -1)
                        announce_map = "Dead Center";
                else if (StrContains(current_map, "c2m") != -1)
                        announce_map = "Dark Carnival";
                else if (StrContains(current_map, "c3m") != -1)
                        announce_map = "Swamp Fever";
                else if (StrContains(current_map, "c4m") != -1)
                        announce_map = "Hard Rain";
		else if (StrContains(current_map, "c5m") != -1)
			announce_map = "The Parish";
		else if (StrContains(current_map, "c6m") != -1)
			announce_map = "The Passing";
                else if (StrContains(current_map, "c7m") != -1)
                        announce_map = "The Sacrifice";
                else if (StrContains(current_map, "c8m") != -1)
                        announce_map = "No Mercy";
		else
			announce_map = current_map;

		PrintToChat(client, "\x01\x03%s\x01 (%s).", announce_map, current_map);

		if (StrEqual(next_mission_force, "none") != true)
		{
			if (StrContains(next_mission_force, "_airport0") != -1)
				announce_map = "Dead Air";
			else if (StrContains(next_mission_force, "_farm0") != -1)
				announce_map = "Blood Harvest";
			else if (StrContains(next_mission_force, "_hospital0") != -1)
				announce_map = "No Mercy";
			else if (StrContains(next_mission_force, "_smalltown0") != -1)
				announce_map = "Death Toll";
                        else if (StrContains(next_mission_force, "_garage0") != -1)
                                announce_map = "Crash Course";
			else if (StrContains(next_mission_force, "sv_lighthouse") != -1)
				announce_map = "Light House";
                        else if (StrContains(next_mission_force, "deathaboard") != -1)
                                announce_map = "Death Aboard";
	                else if (StrContains(next_mission_force, "deathpull") != -1)
	                        announce_map = "Death Pull";
	                else if (StrContains(next_mission_force, "l4d_nt0") != -1)
        	                announce_map = "Night Terror";
	                else if (StrContains(next_mission_force, "deadcity") != -1)
	                        announce_map = "Dead City";
                        else if (StrContains(next_mission_force, "c1m") != -1)
                                announce_map = "Dead Center";
                        else if (StrContains(next_mission_force, "c2m") != -1)
                                announce_map = "Dark Carnival";
                        else if (StrContains(next_mission_force, "c3m") != -1)
                                announce_map = "Swamp Fever";
                        else if (StrContains(next_mission_force, "c4m") != -1)
                                announce_map = "Hard Rain";
			else if (StrContains(next_mission_force, "c5m") != -1)
				announce_map = "The Parish";
                        else if (StrContains(next_mission_force, "c6m") != -1)
                                announce_map = "The Passing";
                        else if (StrContains(next_mission_force, "c7m") != -1)
                                announce_map = "The Sacrifice";
                        else if (StrContains(next_mission_force, "c8m") != -1)
                                announce_map = "No Mercy";

        	        else
				announce_map = next_mission_force;

			if (l4d_gamemode() != 3)
			{
				PrintToChat(client, "\x01\x01Next Campaign: \x03%s\x01.", announce_map);
			}
		}
	}
}

public Action:TimerRoundEndBlock(Handle:timer)
{
	RoundEndBlock = 0;
}

public Action:TimerChDelayVS(Handle:timer)
{
	GetCurrentMap(current_map, 64);

	if (StrContains(current_map, "l4d_garage02_lots") != -1)
		strcopy(next_mission_force, sizeof(next_mission_force), "l4d_vs_smalltown01_caves");

//        if (StrContains(current_map, "c5m5_bridge") != -1)
//		Sub_ResetServerFull("Flushing connection. Please re-connect.");
//	else

	ServerCommand("changelevel %s", next_mission_force);
}

public Action:TimerChDelayCOOP(Handle:timer)
{
	GetCurrentMap(current_map, 64);

        if (StrContains(current_map, "l4d_garage02_lots") != -1)
                strcopy(next_mission_force, sizeof(next_mission_force), "l4d_smalltown01_caves");

//	if (StrContains(current_map, "c5m5_bridge") != -1)
//		Sub_ResetServerFull("Flushing connection. Please re-connect.");
//	else

	ServerCommand("changelevel %s", next_mission_force);
}

public Action:Timer_ResetBotTeam(Handle:hTimer)
{
        SetConVarInt(FindConVar("sb_all_bot_team"), 0);
	//SetConVarInt(FindConVar("allow_all_bot_survivor_team"), 0);
	g_bAllBotsTeam = false;
}

l4d_gamemode()
{
	// 1 - coop / 2 - versus / 3 - survival / or false (thx DDR Khat for code)
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	if (strcmp(gmode, "coop") == 0)
		return 1;
	else if (strcmp(gmode, "versus", false) == 0)
		return 2;
	else if (strcmp(gmode, "teamversus", false) == 0)
                return 2;
        else if (strcmp(gmode, "mutation12", false) == 0)
                return 2;
	else if (strcmp(gmode, "survival", false) == 0)
		return 3;
	else
		return false;
}

stock bool:Sub_HumansInGame(any:client)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (client == 0)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
				return true;
		}

		else
		{
			if (i != client)
			{
				if (IsClientConnected(i) && !IsFakeClient(i))
					return true;
			}
		}
	}

	return false;
}

Sub_ResetServerFull(String:Reason[])
{
	SetConVarInt(FindConVar("sb_all_bot_team"), 1);
        Sub_FlushClients(Reason);
        ServerCommand("quit");
}

Sub_FlushClients(String:Reason[])
{
        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i))
                {
                        KickClient(i, Reason);
                }
        }
}

Sub_ChangeToDefaultMap()
{
        if (!g_bDefMapLoaded)
        {
                LogMessage("[+] Loading Default Map: %s", DEFAULT_MAP);
                ServerCommand("map %s %s", DEFAULT_MAP, DEFAULT_GAMEMODE);
                g_bDefMapLoaded = true;
        }
}
