#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION		"2.0"
#define _DEBUG			0

#define BOTCHECKER_FREQ 	1.0
#define HUD_FREQ		15
#define SPAWN_RETRIES		5

#define INFECTED_HUNTER		1
#define INFECTED_SMOKER		2
#define INFECTED_BOOMER		3
#define INFECTED_TANK		4
#define INFECTED_INDEX_SIZE	5

#define GAMEMODE_COOP		1
#define GAMEMODE_VERSUS		2
#define GAMEMODE_SURVIVAL	3
#define GAMEMODE_NAME(%1)	(%1 == 1 ? "coop" : (%1 == 2 ? "versus" : (%1 == 3 ? "survival" : "Unknown")))

#define TEAM_SPECTATORS		1
#define TEAM_SURVIVORS		2
#define TEAM_INFECTED		3
#define TEAM_CLASS(%1)		(%1 == 1 ? "Hunter" : (%1 == 2 ? "Smoker" : (%1 == 3 ? "Boomer" : (%1 == 4 ? "Tank" : (%1 == 5 ? "Spitter" : (%1 == 6 ? "Charger" : (%1 == 7 ? "Jockey" : (%1 == 8 ? "Boomette" : "Unknown"))))))))
#define TEAM_TYPE(%1)		(%1 == true ? "Bot" : (%1 == false ? "Player" : "Unknown"))

#define INDEX_GHOST 		0
#define INDEX_DEAD  		1
#define INDEX_LIFE  		2
#define INDEX_SIZE  		3

#define L4D_IS_MAPDATAFILE	"l4d_is_mapcfg.txt"
#define L4D_DEFAULT_MAP		"c1m1_hotel"

new Handle:g_hVersusBoomerLimit		= INVALID_HANDLE;
new Handle:g_hVersusHunterLimit		= INVALID_HANDLE;
new Handle:g_hVersusSmokerLimit		= INVALID_HANDLE;
new Handle:g_hCoopBoomerLimit		= INVALID_HANDLE;
new Handle:g_hCoopHunterLimit		= INVALID_HANDLE;
new Handle:g_hCoopSmokerLimit		= INVALID_HANDLE;
new Handle:g_hDefHunterSpawnTime	= INVALID_HANDLE;
new Handle:g_hDefSmokerSpawnTime	= INVALID_HANDLE;
new Handle:g_hDefBoomerSpawnTime	= INVALID_HANDLE;
new Handle:g_hFinaleHunterSpawnTime	= INVALID_HANDLE;
new Handle:g_hFinaleSmokerSpawnTime	= INVALID_HANDLE;
new Handle:g_hFinaleBoomerSpawnTime	= INVALID_HANDLE;
new Handle:g_hBotHudEnabled		= INVALID_HANDLE;

new Handle:g_hSpawnTimer[INFECTED_INDEX_SIZE] = {INVALID_HANDLE, ...};

new g_iMaxInfected;
new g_iMaxHunters;
new g_iMaxBoomers;
new g_iMaxSmokers;
new g_iMaxSpitters;
new g_iMaxChargers;
new g_iMaxJockeys;
new g_iMaxTanks;
new g_iMaxRetries;
new g_iHunterCount;
new g_iSmokerCount;
new g_iBoomerCount;
new g_iSpitterCount;
new g_iChargerCount;
new g_iJockeyCount;
new g_iTankCount;
new g_iHunter_SpawnTime;
new g_iSmoker_SpawnTime;
new g_iBoomer_SpawnTime;
new g_iSpitter_SpawnTime;
new g_iCharger_SpawnTime;
new g_iJockey_SpawnTime;
new g_iTank_SpawnTime;
new g_iKvHunter_SpawnTime;
new g_iKvSmoker_SpawnTime;
new g_iKvBoomer_SpawnTime;
new g_iKvSpitter_SpawnTime;
new g_iKvCharger_SpawnTime;
new g_iKvJockey_SpawnTime;
new g_bIsFirstMap;
new g_iGameMode;
new g_iInfected[INDEX_SIZE][MAXPLAYERS+1];

new bool:g_bTankCheckOnce;
new bool:g_bMapEnded;
new bool:g_bRoundStarted;
new bool:g_bRoundEnded;
new bool:g_bLeftSafeRoom;
new bool:g_bIsFirstRound;
new bool:g_bBoomerClass;
new bool:g_bSmokerClass;
new bool:g_bHunterClass;
new bool:g_bSpitterClass;
new bool:g_bChargerClass;
new bool:g_bJockeyClass;
new bool:g_bTankClass;
new bool:g_bBoomerSpawned;
new bool:g_bSmokerSpawned;
new bool:g_bHunterSpawned;
new bool:g_bSpitterSpawned;
new bool:g_bChargerSpawned;
new bool:g_bJockeySpawned;
new bool:g_bTankSpawned;
new bool:g_bResetSpawn;
new bool:g_bAllBotsTeam;

public Plugin:myinfo =
{
	name = "Infected Spawns +",
	author = "XBetaAlpha",
	description = "Spawns Infected in L4D2",
	version = PLUGIN_VERSION,
	url = "www.andrewx.net"
}

public OnPluginStart()
{
	CreateConVar("l4d_is_version", PLUGIN_VERSION, "Version of L4D2+ Infected Spawns", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	//RegConsoleCmd("sm_infected", Command_SwitchToInfected, "Switch to Infected.");
	//RegConsoleCmd("sm_survivor", Command_SwitchToSurvivor, "Switch to Survivor.");

	g_hVersusHunterLimit		= CreateConVar("l4d_is_versus_hunter_limit",	  	"1" , "Hunter spawn limit - VS.");
	g_hVersusSmokerLimit		= CreateConVar("l4d_is_versus_smoker_limit",	  	"1" , "Smoker spawn limit - VS.");
	g_hVersusBoomerLimit		= CreateConVar("l4d_is_versus_boomer_limit",	  	"1" , "Boomer spawn limit - VS.");
	g_hCoopHunterLimit		= CreateConVar("l4d_is_coop_hunter_limit",	  	"1" , "Hunter spawn limit - COOP.");
	g_hCoopSmokerLimit		= CreateConVar("l4d_is_coop_smoker_limit",	  	"1" , "Smoker spawn limit - COOP.");
	g_hCoopBoomerLimit		= CreateConVar("l4d_is_coop_boomer_limit",	  	"1" , "Boomer spawn limit - COOP.");
	g_hDefHunterSpawnTime	 	= CreateConVar("l4d_is_def_hunter_spawntime",	  	"20", "Hunter spawntime (s) - Default.");
	g_hDefSmokerSpawnTime	 	= CreateConVar("l4d_is_def_smoker_spawntime",	  	"25", "Hunter spawntime (s) - Default.");
	g_hDefBoomerSpawnTime		= CreateConVar("l4d_is_def_boomer_spawntime",		"35", "Hunter spawntime (s) - Default.");
	g_hFinaleHunterSpawnTime	= CreateConVar("l4d_is_finale_hunter_spawntime",	"10", "Hunter spawntime (s) - Finale.");
	g_hFinaleSmokerSpawnTime	= CreateConVar("l4d_is_finale_smoker_spawntime",	"10", "Smoker spawntime (s) - Finale.");
	g_hFinaleBoomerSpawnTime	= CreateConVar("l4d_is_finale_boomer_spawntime",	"15", "Boomer spawntime (s) - Finale.");
	g_hBotHudEnabled		= CreateConVar("l4d_is_showhud",			"1" , "Show Infected Bot HUD.");

	AutoExecConfig(true, "l4d_is");

	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	//HookEvent("tank_spawn", Event_TankSpawn);
	//HookEvent("player_left_checkpoint", Event_PlayerLeftCheckPoint, EventHookMode_Pre);
	HookEvent("door_open", Event_DoorOpen);
	HookEvent("finale_start", Event_FinaleStart);

	g_bMapEnded = false;
	g_bRoundStarted = false;
	g_bRoundEnded = false;
	g_bIsFirstRound = true;
	g_bAllBotsTeam = false;
}

public OnPluginEnd()
{
	ResetConVar(FindConVar("director_no_specials"), true, true);
	ResetConVar(FindConVar("z_attack_flow_range"), true, true);
	ResetConVar(FindConVar("director_spectate_specials"), true, true);
	ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
	ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
	ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
	ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
	ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
	ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
	ResetConVar(FindConVar("boomer_exposed_time_tolerance"), true, true);
	ResetConVar(FindConVar("z_spawn_safety_range"), true, true);
	ResetConVar(FindConVar("z_spawn_flow_limit"), true, true);
}

Sub_GameCvarSetup(_iGameMode)
{
	switch (_iGameMode)
	{
		case GAMEMODE_COOP:
		{
                        SetConVarInt(FindConVar("boomer_vomit_delay"), 0);
                        SetConVarInt(FindConVar("smoker_tongue_delay"), 0);
                        SetConVarInt(FindConVar("hunter_leap_away_give_up_range"), 0);
                        SetConVarInt(FindConVar("director_spectate_specials"), 1);
                        SetConVarInt(FindConVar("boomer_exposed_time_tolerance"), 0);

			SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
			ResetConVar(FindConVar("director_no_specials"), true, true);
			ResetConVar(FindConVar("director_spectate_specials"), true, true);
			ResetConVar(FindConVar("boomer_exposed_time_tolerance"), true, true);

			g_iMaxInfected = GetConVarInt(FindConVar("z_max_player_zombies"));
			g_iMaxBoomers = GetConVarInt(g_hCoopBoomerLimit);
			g_iMaxSmokers = GetConVarInt(g_hCoopSmokerLimit);
			g_iMaxHunters = GetConVarInt(g_hCoopHunterLimit);
			g_iMaxSpitters = 1;
			g_iMaxChargers = 1;
			g_iMaxJockeys = 1;
			g_iMaxTanks = 1;
		}
		case GAMEMODE_VERSUS:
		{
			ResetConVar(FindConVar("director_no_specials"), true, true);

			g_iMaxInfected = GetConVarInt(FindConVar("z_max_player_zombies"));
			g_iMaxBoomers = GetConVarInt(g_hVersusBoomerLimit);
			g_iMaxSmokers = GetConVarInt(g_hVersusSmokerLimit);
			g_iMaxHunters = GetConVarInt(g_hVersusHunterLimit);
                        g_iMaxSpitters = 1;
                        g_iMaxChargers = 1;
                        g_iMaxJockeys = 1;
			g_iMaxTanks = 1;
		}
		case GAMEMODE_SURVIVAL:
		{
			ResetConVar(FindConVar("director_no_specials"), true, true);
			ResetConVar(FindConVar("z_attack_flow_range"), true, true);
			ResetConVar(FindConVar("director_spectate_specials"), true, true);
			ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
			ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
			ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
			ResetConVar(FindConVar("boomer_vomit_delay"), true, true);
			ResetConVar(FindConVar("smoker_tongue_delay"), true, true);
			ResetConVar(FindConVar("hunter_leap_away_give_up_range"), true, true);
			ResetConVar(FindConVar("boomer_exposed_time_tolerance"), true, true);
			ResetConVar(FindConVar("z_spawn_safety_range"), true, true);
			ResetConVar(FindConVar("z_spawn_flow_limit"), true, true);

                	g_iMaxInfected = GetConVarInt(FindConVar("holdout_max_specials"));
                	g_iMaxBoomers = GetConVarInt(FindConVar("holdout_max_boomers"));
                	g_iMaxSmokers = GetConVarInt(FindConVar("holdout_max_smokers"));
                	g_iMaxHunters = GetConVarInt(FindConVar("holdout_max_hunters"));
                        g_iMaxSpitters = 1;
                        g_iMaxChargers = 1;
                        g_iMaxJockeys = 1;
			g_iMaxTanks = 1;
		}
	}
	LogMessage("[+] S_GCS: Game Mode (%s): Initialising settings.", GAMEMODE_NAME(_iGameMode));
}

/*
public Action:Command_SwitchToInfected(_iClient, args)
{
	if (!g_bTimeOut[_iClient])
	{
		PrintToChat(_iClient, "Cannot switch teams right now.");
		return Plugin_Continue;
	}

	if (IsClientConnected(_iClient) && IsClientInGame(_iClient) && !IsFakeClient(_iClient))
		if (GetClientTeam(_iClient) == TEAM_INFECTED)
			PrintToChat(_iClient, "You are already on the infected team.");

		else if (Sub_CountInfectedTeam() >= GetConVarInt(g_hMaxPlayerZombies))
				PrintToChat(_iClient, "Team is full (Max: %d Infected).", GetConVarInt(g_hMaxPlayerZombies));
		else
			ChangeClientTeam(_iClient, TEAM_INFECTED);

	return Plugin_Continue;
}

public Action:Command_SwitchToSurvivor(_iClient, args)
{
	if (!g_bTimeOut[_iClient])
        {
                PrintToChat(_iClient, "Cannot switch teams right now.");
                return Plugin_Continue;
        }

        if (IsClientConnected(_iClient) && IsClientInGame(_iClient) && !IsFakeClient(_iClient))
	{
		if (GetClientTeam(_iClient) == TEAM_SURVIVORS)
			PrintToChat(_iClient, "You are already on the survivor team.");
		else
		{
                	SetCommandFlags("sb_takecontrol", GetCommandFlags("sb_takecontrol") & ~FCVAR_CHEAT);
			FakeClientCommand(_iClient, "sb_takecontrol");
                	SetCommandFlags("sb_takecontrol", GetCommandFlags("sb_takecontrol")|FCVAR_CHEAT);
		}
	}

	return Plugin_Continue;
}
*/

public Action:Event_RoundStart (Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bRoundStarted)
	{
		g_bRoundEnded = false;
		g_bRoundStarted = true;
		g_bLeftSafeRoom = false;
		g_bTankCheckOnce = false;

		if (!g_bIsFirstRound)
		{
			if (g_iGameMode != GAMEMODE_SURVIVAL)
	                {
				g_iGameMode = Sub_CheckGameMode();
				Sub_GameCvarSetup(g_iGameMode);

/*				for (new i = 1; i <= MaxClients; i++)
				{
					g_bHasSpawned[i] = false;
					g_bTimeOut[i] = true;

					if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
                                	{
                                	        if (g_iClientTeams[i] == TEAM_INFECTED)
							CreateTimer(BOTCHECKER_FREQ, Timer_TeamSwap, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	                                        if (GetClientTeam(i) == TEAM_INFECTED)
	                                                CreateTimer((BOTCHECKER_FREQ*2), Timer_StartSpawn, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
                                	}
				}
*/
				g_bHunterClass = false;
				g_bSmokerClass = false;
				g_bBoomerClass = false;
				g_bSpitterClass = false;
				g_bChargerClass = false;
				g_bJockeyClass = false;
				g_bTankClass = false;

				g_iHunter_SpawnTime = g_iKvHunter_SpawnTime;
				g_iSmoker_SpawnTime = g_iKvSmoker_SpawnTime;
				g_iBoomer_SpawnTime = g_iKvBoomer_SpawnTime;
				g_iSpitter_SpawnTime = g_iKvSpitter_SpawnTime;
				g_iCharger_SpawnTime = g_iKvCharger_SpawnTime;
				g_iJockey_SpawnTime = g_iKvJockey_SpawnTime;
				g_iTank_SpawnTime = GetRandomInt(90,180);

				LogMessage("[+] E_RS: Level SpawnTimes (Hunter:%ds Smoker:%ds Boomer:%ds Spitter:%ds Charger:%ds Jockey:%ds)", g_iHunter_SpawnTime, g_iSmoker_SpawnTime, g_iBoomer_SpawnTime, g_iSpitter_SpawnTime, g_iCharger_SpawnTime, g_iJockey_SpawnTime);
			}
		}
	}
}

/*
public Action:Timer_TeamSwap (Handle:_hTimer, any:_iClient)
{
	if (g_bRoundEnded || g_bMapEnded)
		return Plugin_Stop;

	if (IsClientConnected(_iClient) && IsClientInGame(_iClient) && !IsFakeClient(_iClient))
	{
		if (GetClientTeam(_iClient) == TEAM_INFECTED)
			return Plugin_Stop;
		else
			ChangeClientTeam(_iClient, g_iClientTeams[_iClient]);
	}

	return Plugin_Continue;
}

public Action:Timer_StartSpawn (Handle:_hTimer, any:_iClient)
{
	if (g_bMapEnded || g_bRoundEnded)
		return Plugin_Stop;

	if (!IsClientInGame(_iClient))
		return Plugin_Stop;

        if (IsPlayerAlive(_iClient) && (GetClientHealth(_iClient) > 0))
                return Plugin_Stop;

	new _iClass = GetRandomInt(1,7);

	if (!g_bHasSpawned[_iClient] && !IsFakeClient(_iClient))
	{
        	SetCommandFlags("z_spawn", GetCommandFlags("z_spawn") & ~FCVAR_CHEAT);

		if (_iClass == INFECTED_TANK)
		{
			if (g_iTankLimit < 1 && g_bLeftSafeRoom)
			{
				FakeClientCommand(_iClient, "z_spawn tank auto");
				g_iTankLimit++;
			}
			else
			{
				_iClass = GetRandomInt(1,3);
				FakeClientCommand(_iClient, "z_spawn %s auto", TEAM_CLASS(_iClass));
			}
		}
		else
		{
			FakeClientCommand(_iClient, "z_spawn %s auto", TEAM_CLASS(_iClass));
		}

		SetCommandFlags("z_spawn", GetCommandFlags("z_spawn")|FCVAR_CHEAT);

		if (IsPlayerAlive(_iClient) && (GetClientHealth(_iClient) > 0))
			g_bHasSpawned[_iClient] = true;
	}

	return Plugin_Continue;
}

public Action:Timer_Culling (Handle:_hTimer, any:_iClient)
{
	if (g_bRoundEnded || g_bMapEnded)
		return Plugin_Stop;

	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient))
	{
		if (IsValidEntity(_iClient))
		{
			if (GetEntProp(_iClient,Prop_Send,"m_isGhost") == 1)
				return Plugin_Stop;
			else
			{
				SetEntProp(_iClient,Prop_Send,"m_isCulling", 1, 1);
				ClientCommand(_iClient, "+use");
			}
		}
	}

	LogMessage("[X] Ensure client %N (%d) becomes ghost.", _iClient, _iClient);

	return Plugin_Continue;
}

public Action:Timer_Versus_Wait (Handle:_hTimer, any:_iClient)
{
	if (g_bMapEnded || g_bRoundEnded)
	{
		if (IsClientConnected(_iClient) && IsClientInGame(_iClient))
			ChangeClientTeam(_iClient, TEAM_INFECTED);
		return Plugin_Stop;
	}

	if (IsClientConnected(_iClient) && IsClientInGame(_iClient))
	{
		if (g_iVsCounter[_iClient] == 0)
		{
			ChangeClientTeam(_iClient, TEAM_INFECTED);

			if (IsValidEntity(_iClient))
				SetEntProp(_iClient,Prop_Send,"m_scrimmageType", 0);

			CreateTimer(1.5, Timer_StartSpawn, _iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			g_bTimeOut[_iClient] = true;
			return Plugin_Stop;
		}

		PrintHintText(_iClient, "You are dead. Next infected respawn in %ds...", g_iVsCounter[_iClient]);
		g_iVsCounter[_iClient]--;
		g_bTimeOut[_iClient] = false;
	}

	return Plugin_Continue;
}
*/

public Action:Event_RoundEnd (Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bRoundEnded)
	{
		g_bRoundEnded = true;
		g_bRoundStarted = false;
		g_bLeftSafeRoom = false;
		g_bIsFirstRound = false;

		for (new i = 1; i < INFECTED_INDEX_SIZE; i++)
		{
			g_hSpawnTimer[i] = INVALID_HANDLE;
		}
/*
	        for (new i = 1; i <= MaxClients; i++)
	        {
	                if (IsClientConnected(i) && IsClientInGame(i))
			{
				if (GetClientTeam(i) == TEAM_INFECTED || (GetClientTeam(i) == TEAM_SPECTATORS && !g_bTimeOut[i]))
	                        	g_iClientTeams[i] = TEAM_INFECTED;

				if (GetClientTeam(i) == TEAM_SURVIVORS)
					g_iClientTeams[i] = TEAM_SURVIVORS;

				if (GetClientTeam(i) == TEAM_SPECTATORS && g_bTimeOut[i])
					g_iClientTeams[i] = TEAM_SPECTATORS;
			}
	        }
*/
	}
}

public OnMapStart()
{
	g_bLeftSafeRoom = false;
	g_bRoundEnded = false;
	g_bMapEnded = false;
	g_bIsFirstRound = true;
	g_bTankCheckOnce = false;

	g_iGameMode = Sub_CheckGameMode();
	Sub_GameCvarSetup(g_iGameMode);

        decl String:current_map[64];
        GetCurrentMap(current_map, sizeof(current_map));

        if (StrContains(current_map, "m1_") == -1)
                g_bIsFirstMap = false;
        else
                g_bIsFirstMap = true;

	if (g_bIsFirstRound)
	{
		if (g_iGameMode != GAMEMODE_SURVIVAL)
		{
/*			for (new i = 1; i <= MaxClients; i++)
			{
				g_bHasSpawned[i] = false;
				g_bTimeOut[i] = true;

				if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
				{
                                	if (g_iClientTeams[i] == TEAM_INFECTED)
                                        	CreateTimer(BOTCHECKER_FREQ, Timer_TeamSwap, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	                                if (GetClientTeam(i) == TEAM_INFECTED)
                                	        CreateTimer((BOTCHECKER_FREQ*2), Timer_StartSpawn, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				}
			}
*/
			g_bHunterClass = false;
			g_bSmokerClass = false;
			g_bBoomerClass = false;
			g_bSpitterClass = false;
			g_bChargerClass = false;
			g_bJockeyClass = false;
			g_bTankClass = false;

			Sub_GetFileAttribute();

			g_iHunter_SpawnTime = g_iKvHunter_SpawnTime;
			g_iSmoker_SpawnTime = g_iKvSmoker_SpawnTime;
			g_iBoomer_SpawnTime = g_iKvBoomer_SpawnTime;
			g_iSpitter_SpawnTime = g_iKvSpitter_SpawnTime;
			g_iCharger_SpawnTime = g_iKvCharger_SpawnTime;
			g_iJockey_SpawnTime = g_iKvJockey_SpawnTime;
			g_iTank_SpawnTime = GetRandomInt(90,180);

			LogMessage("[+] E_MS: Level SpawnTimes (Hunter:%ds Smoker:%ds Boomer:%ds Spitter:%ds Charger:%ds Jockey:%ds)", g_iHunter_SpawnTime, g_iSmoker_SpawnTime, g_iBoomer_SpawnTime, g_iSpitter_SpawnTime, g_iCharger_SpawnTime, g_iJockey_SpawnTime);
		}
	}
}

public OnMapEnd()
{
	g_bRoundStarted = false;
	g_bRoundEnded = true;
	g_bLeftSafeRoom = false;
	g_bMapEnded = true;
	g_bIsFirstRound = true;
}

public bool:OnClientConnect(_iClient, String: rejectmsg[], maxlen)
{
        if(_iClient && !IsFakeClient(_iClient))
        {
                if (!g_bAllBotsTeam)
                {
                        SetConVarInt(FindConVar("sb_all_bot_team"), 1);
                        g_bAllBotsTeam = true;
                }
        }

	return true;
}

public OnClientDisconnect(_iClient)
{
	if (IsFakeClient(_iClient))
		return;

        if (!Sub_RealPlayerCount(_iClient))
        {
		//SetConVarInt(FindConVar("sb_all_bot_team"), 0);
                g_bAllBotsTeam = false;
        }
}

public Action:Event_PlayerLeftStartArea(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode == GAMEMODE_SURVIVAL)
		return Plugin_Continue;

	if (!g_bLeftSafeRoom)
	{
		g_bLeftSafeRoom = true;

		Sub_InfectedSpawnDelay(INFECTED_HUNTER);
		Sub_InfectedSpawnDelay(INFECTED_SMOKER);
		Sub_InfectedSpawnDelay(INFECTED_BOOMER);

		/*if (IsProhibitedMap())
		{
			LogMessage("[+] E_PLSA: Prohibited Map Detected, Spawning Tank in: %ds", g_iTank_SpawnTime);
			Sub_InfectedSpawnDelay(INFECTED_TANK);
		}*/
#if _DEBUG
		LogMessage("[+] E_PLSA: Infected Spawns Triggered. (Delayed)");
#endif
	}

	return Plugin_Continue;
}

/*
public Action:Event_PlayerLeftCheckPoint(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsFirstMap)
		return Plugin_Continue;

	new _iClient = GetClientOfUserId(GetEventInt(_hEvent, "userid"));

	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient) && !IsFakeClient(_iClient) && GetClientTeam(_iClient) == TEAM_SURVIVORS)
	{
		if (g_bRoundStarted && !g_bMapEnded && !g_bIsFirstRound)
		{
			if (!g_bLeftSafeRoom)
			{
				g_bLeftSafeRoom = true;

				Sub_InfectedSpawnDelay(INFECTED_HUNTER);
				Sub_InfectedSpawnDelay(INFECTED_SMOKER);
				Sub_InfectedSpawnDelay(INFECTED_BOOMER);
#if _DEBUG
				LogMessage("[+] E_PLCP: Infected Spawns Triggered. (Delayed)");
#endif
			}
		}

        }

	return Plugin_Continue;
}
*/

public Action:Event_DoorOpen(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode == GAMEMODE_SURVIVAL)
		return Plugin_Continue;

	if (!g_bLeftSafeRoom)
	{
		if (GetEventBool(_hEvent, "checkpoint"))
		{
			g_bLeftSafeRoom = true;

			Sub_InfectedSpawnDelay(INFECTED_HUNTER);
			Sub_InfectedSpawnDelay(INFECTED_SMOKER);
			Sub_InfectedSpawnDelay(INFECTED_BOOMER);

			/*if (IsProhibitedMap())
			{
				LogMessage("[+] E_PLDO: Prohibited Map Detected, Spawning Tank in: %ds", g_iTank_SpawnTime);
				Sub_InfectedSpawnDelay(INFECTED_TANK);
			}*/
#if _DEBUG
			LogMessage("[+] E_PLDO: Infected Spawns Triggered. (Delayed)");
#endif
		}
	}

	return Plugin_Continue;
}


public Action:Event_TankSpawn(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	new _iClient = GetClientOfUserId(GetEventInt(_hEvent, "userid"));
	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient))
	{
		if (IsValidEntity(_iClient))
		{
			SetEntProp(_iClient,Prop_Send,"m_iHealth",12000);
			SetEntProp(_iClient,Prop_Send,"m_iMaxHealth",12000);
			//SetEntityRenderMode(_iClient, RENDER_TRANSCOLOR);
			//SetEntityRenderColor(_iClient, 16, 224, 84, 255);
		}
	}
}

public Action:Event_FinaleStart(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode == GAMEMODE_SURVIVAL)
		return Plugin_Continue;

	g_iHunter_SpawnTime = GetConVarInt(g_hFinaleHunterSpawnTime);
	g_iSmoker_SpawnTime = GetConVarInt(g_hFinaleSmokerSpawnTime);
	g_iBoomer_SpawnTime = GetConVarInt(g_hFinaleBoomerSpawnTime);

	for (new i = 1; i < INFECTED_INDEX_SIZE; i++)
	{
		g_hSpawnTimer[i] = INVALID_HANDLE;
	}

	Sub_InfectedSpawnDelay(INFECTED_HUNTER);
	Sub_InfectedSpawnDelay(INFECTED_SMOKER);
	Sub_InfectedSpawnDelay(INFECTED_BOOMER);

	decl String:_sMap[64];
        GetCurrentMap(_sMap, sizeof(_sMap));

        if (StrContains(_sMap, "c3m1_plankcountry") != -1)
		PrintToChatAll("\x04Note: Boat has been triggered. Infected may be unable to respawn until boat arrives. Blame Valve!");

#if _DEBUG
	LogMessage("[+] E_FS: Finale SpawnTimes (Hunter:%ds Smoker:%ds Boomer:%ds)", g_iHunter_SpawnTime, g_iSmoker_SpawnTime, g_iBoomer_SpawnTime);
#endif
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode == GAMEMODE_SURVIVAL)
		return Plugin_Continue;

	if (g_bRoundEnded || g_bMapEnded)
		return Plugin_Continue;

	new _iClient = GetClientOfUserId(GetEventInt(_hEvent, "userid"));
	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient) && GetClientTeam(_iClient) == TEAM_INFECTED)
	{
		if (g_bLeftSafeRoom)
		{
			new _iClass = 0;
			new bool:_bType = IsFakeClient(_iClient) ? true : false;

			switch (Sub_GetClass(_iClient))
			{
				case INFECTED_HUNTER:
				{
					_iClass = INFECTED_HUNTER;
					g_bHunterSpawned = true;
					g_bResetSpawn = true;
				}
				case INFECTED_SMOKER:
				{
					_iClass = INFECTED_SMOKER;
					g_bSmokerSpawned = true;
					g_bResetSpawn = true;
				}
				case INFECTED_BOOMER:
				{
					_iClass = INFECTED_BOOMER;
					g_bBoomerSpawned = true;
					g_bResetSpawn = true;
				}
				case INFECTED_TANK:
				{
					_iClass = INFECTED_TANK;
					if (!g_bTankCheckOnce)
					{
						g_bTankCheckOnce = true;
						CreateTimer(1.0, Timer_ShowInfectedTankHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
#if _DEBUG
			LogMessage("[+] E_PS: Spawned %s. (%s, %N (%d))", TEAM_CLASS(_iClass), TEAM_TYPE(_bType), _iClient, _iClient);
#endif
			Sub_CheckBotQueue();
                	Show_InfectedHud();
		}
/*
		if (!IsFakeClient(_iClient) && !g_bHasSpawned[_iClient])
		{
			if (IsPlayerAlive(_iClient))
				g_bHasSpawned[_iClient] = true;
			CreateTimer(0.1, Timer_Culling, _iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
*/
	}

	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode != GAMEMODE_VERSUS)
		return Plugin_Continue;

	if (g_bRoundEnded || g_bMapEnded || !g_bLeftSafeRoom)
		return Plugin_Continue;

	new _iClient = GetClientOfUserId(GetEventInt(_hEvent, "userid"));

	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient))
	{
		if (!IsFakeClient(_iClient))
		{
			new _iNewTeam = GetEventInt(_hEvent, "team");
			new _iOldTeam = GetEventInt(_hEvent, "oldteam");

			//LogMessage("[+] PLAYERTEAM: %N, OldTeam: %d, NewTeam: %d", _iClient, _iOldTeam, _iNewTeam);

			if (_iOldTeam == TEAM_INFECTED || _iNewTeam == TEAM_INFECTED)
			{
				//if (g_iInfected[INDEX_LIFE][_iClient] != 1)
				//{
#if _DEBUG
					LogMessage("[+] E_PT: Player %N Switched Team.", _iClient);
#endif
					//g_bHasSpawned[_iClient] = false;
					//CreateTimer((BOTCHECKER_FREQ*2), Timer_StartSpawn, _iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

					Show_InfectedHud();
				//}
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:_hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_iGameMode == GAMEMODE_SURVIVAL)
		return Plugin_Continue;

	if (g_bRoundEnded || g_bMapEnded)
		return Plugin_Continue;

	new _iClient = GetClientOfUserId(GetEventInt(_hEvent, "userid"));

	if (_iClient != 0 && IsClientConnected(_iClient) && IsClientInGame(_iClient) && GetClientTeam(_iClient) == TEAM_INFECTED)
	{
		if (g_bLeftSafeRoom)
		{
			new _iClass = 0;
			new bool:_bType = IsFakeClient(_iClient) ? true : false;

			switch (Sub_GetClass(_iClient))
			{
				case INFECTED_HUNTER:
				{
					_iClass = INFECTED_HUNTER;
					Sub_InfectedSpawnDelay(INFECTED_HUNTER);
				}
				case INFECTED_SMOKER:
				{
					_iClass = INFECTED_SMOKER;
					Sub_InfectedSpawnDelay(INFECTED_SMOKER);
				}
				case INFECTED_BOOMER:
				{
					_iClass = INFECTED_BOOMER;
					Sub_InfectedSpawnDelay(INFECTED_BOOMER);
				}
				case INFECTED_TANK:
				{
					_iClass = INFECTED_TANK;
				}
			}
#if _DEBUG
			LogMessage("[+] E_PS: %s Died. (%s, %N, (%d))", TEAM_CLASS(_iClass), TEAM_TYPE(_bType), _iClient, _iClient);
#endif
			if (IsFakeClient(_iClient))
				CreateTimer(BOTCHECKER_FREQ/10, Timer_KickFakeClient, _iClient, TIMER_FLAG_NO_MAPCHANGE);
        	        Show_InfectedHud();
		}

/*		if (!IsFakeClient(_iClient) && g_bHasSpawned[_iClient])
		{
			if (!IsPlayerAlive(_iClient))
				g_bHasSpawned[_iClient] = false;

			new _iVsCount = 0;
			for (new i = 1; (i <= MaxClients); i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
					_iVsCount++;
			}

                        ChangeClientTeam(_iClient, TEAM_SPECTATORS);

			g_iVsCounter[_iClient] = (_iVsCount * 4);
			CreateTimer(1.0, Timer_Versus_Wait, _iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
*/
	}

	return Plugin_Continue;
}

/*
Sub_CountInfectedTeam()
{
	new _iInfectedCount;

	for (new i = 1; (i <= MaxClients); i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_INFECTED || (GetClientTeam(i) == TEAM_SPECTATORS && !g_bTimeOut[i]))
				_iInfectedCount++;
	}

	return _iInfectedCount;
}
*/

Sub_InfectedSpawnDelay(any:_iInfectedType)
{
	new _iSpawnTime = 0;
	new _iType = 0;

	switch (_iInfectedType)
	{
		case INFECTED_HUNTER:
		{
			g_bHunterClass = false;
			_iType = INFECTED_HUNTER;
			_iSpawnTime = (g_iHunter_SpawnTime - 1);
		}
		case INFECTED_SMOKER:
		{
			g_bSmokerClass = false;
			_iType = INFECTED_SMOKER;
			_iSpawnTime = (g_iSmoker_SpawnTime - 1);
		}
		case INFECTED_BOOMER:
		{
			g_bBoomerClass = false;
			_iType = INFECTED_BOOMER;
			_iSpawnTime = (g_iBoomer_SpawnTime - 1);
		}
		case INFECTED_TANK:
		{
			g_bTankClass = false;
			_iType = INFECTED_TANK;
			_iSpawnTime = (g_iTank_SpawnTime - 1);
		}
	}

	g_hSpawnTimer[_iType] = CreateTimer(float(_iSpawnTime), Timer_ResetClass, _iType, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ResetClass(Handle:_hTimer, any:_iInfectedType)
{
        if (g_bRoundEnded || g_bMapEnded || !g_bLeftSafeRoom)
                return Plugin_Continue;

        switch (_iInfectedType)
        {
                case INFECTED_HUNTER: g_bHunterClass = true;
                case INFECTED_SMOKER: g_bSmokerClass = true;
                case INFECTED_BOOMER: g_bBoomerClass = true;
		case INFECTED_TANK: g_bTankClass = true;
        }

	g_bResetSpawn = false;
	Sub_CheckBotQueue();

	return Plugin_Continue;
}

Sub_CheckBotQueue()
{
	if (g_bRoundEnded || g_bMapEnded || !g_bLeftSafeRoom)
		return;

	g_iMaxRetries = SPAWN_RETRIES;
	new _iInfectedCount = Sub_CountInfectedClass(false,true);

	if (_iInfectedCount > g_iMaxInfected)
	{
		new _iBotsOver = (_iInfectedCount - g_iMaxInfected);
		new _iBotsKicked = 0;
		for (new i = 1; (i <= MaxClients) && (_iBotsKicked < _iBotsOver); i++)
		{
			if (IsClientConnected(i) && IsFakeClient(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			{
				if (Sub_GetClass(i) != INFECTED_TANK)
				{
					CreateTimer(BOTCHECKER_FREQ/10, Timer_KickFakeClient, i, TIMER_FLAG_NO_MAPCHANGE);
					_iBotsKicked++;
				}
			}
		}
	}

	if (_iInfectedCount < g_iMaxInfected)
	{
		for (new i = 1; i < (g_iMaxInfected - _iInfectedCount); i++)
		{
			CreateTimer(BOTCHECKER_FREQ, Timer_SpawnInfectedClass, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

/*
public Action:Timer_AnnounceCommands(Handle:_hTimer, any:_iClient)
{
	if (IsClientInGame(_iClient))
	{
		PrintToChat(_iClient, "\x01Type \x03!infected\x01 to change to \x03infected\x01 team.");
		PrintToChat(_iClient, "\x01Type \x03!survivor\x01 to change to \x03survivor\x01 team.");
	}
}
*/

public Action:Timer_RestartGame(Handle:_hTimer)
{
        if (g_bIsFirstMap)
	{
		LogMessage("[X] Restarting Game...");
		SetConVarInt(FindConVar("mp_restartgame"), 1);
	}
}

public Action:Timer_SpawnInfectedClass(Handle:_hTimer)
{
	if (g_bRoundEnded || g_bMapEnded || !g_bLeftSafeRoom)
		return Plugin_Continue;

	new _iInfectedAlive = Sub_CountInfectedClass(true,true);

	if (_iInfectedAlive >= g_iMaxInfected)
		return Plugin_Continue;

	Sub_InfectedEntitySet(false, true);

	new _iClient = Sub_CreateFakeClient();

	SetCommandFlags("z_spawn", GetCommandFlags("z_spawn") & ~FCVAR_CHEAT);

	if (g_bHunterClass)
	{
		if (g_iHunterCount < g_iMaxHunters)
		{
			if (IsClientConnected(_iClient))
			{
				g_bHunterSpawned = false;
				FakeClientCommand(_iClient, "z_spawn hunter auto");
			}
		}
		else
			g_bHunterClass = false;
	}

	if (g_bSmokerClass)
	{
		if (g_iSmokerCount < g_iMaxSmokers)
		{
			if (IsClientConnected(_iClient))
			{
				g_bSmokerSpawned = false;
				FakeClientCommand(_iClient, "z_spawn smoker auto");
			}
		}
		else
			g_bSmokerClass = false;
	}

	if (g_bBoomerClass)
	{
		if (g_iBoomerCount < g_iMaxBoomers)
		{
			if (IsClientConnected(_iClient))
			{
				g_bBoomerSpawned = false;
				FakeClientCommand(_iClient, "z_spawn boomer auto");
			}
		}
		else
			g_bBoomerClass = false;
	}

	if (g_bSpitterClass)
	{
		if (g_iSpitterCount < g_iMaxSpitters)
		{
			if (IsClientConnected(_iClient))
			{
				g_bSpitterSpawned = false;
				FakeClientCommand(_iClient, "z_spawn spitter auto");
			}
		}
		else
			g_bSpitterClass = false;
	}

	if (g_bChargerClass)
	{
		if (g_iChargerCount < g_iMaxChargers)
		{
			if (IsClientConnected(_iClient))
			{
				g_bChargerSpawned = false;
				FakeClientCommand(_iClient, "z_spawn charger auto");
			}
		}
		else
			g_bChargerClass = false;
	}

	if (g_bJockeyClass)
	{
		if (g_iJockeyCount < g_iMaxJockeys)
		{
			if (IsClientConnected(_iClient))
			{
				g_bJockeySpawned = false;
				FakeClientCommand(_iClient, "z_spawn jockey auto");
			}
		}
		else
			g_bJockeyClass = false;
	}

	if (g_bTankClass)
	{
                if (g_iTankCount < g_iMaxTanks)
                {
                        if (IsClientConnected(_iClient))
                        {
                                g_bTankSpawned = false;
                                FakeClientCommand(_iClient, "z_spawn tank auto");
                        }
                }
                else
                        g_bTankClass = false;
        }

	SetCommandFlags("z_spawn", GetCommandFlags("z_spawn")|FCVAR_CHEAT);

	if (IsFakeClient(_iClient))
	{
		CreateTimer(0.5, Timer_KickFakeClient, _iClient, TIMER_FLAG_NO_MAPCHANGE);
	}

	Sub_InfectedEntitySet(true, false);

	if (!g_bResetSpawn)
	{
		if (!g_bHunterSpawned || !g_bSmokerSpawned || !g_bBoomerSpawned || !g_bSpitterSpawned || !g_bChargerSpawned || !g_bJockeySpawned || !g_bTankSpawned)
		{
			if (_iInfectedAlive < g_iMaxInfected)
			{
				if (g_iMaxRetries > 0)
				{
					g_bResetSpawn = false;
					CreateTimer((BOTCHECKER_FREQ*5), Timer_SpawnInfectedClass, _, TIMER_FLAG_NO_MAPCHANGE);
					g_iMaxRetries--;
#if _DEBUG
					LogMessage("[+] T_SIC: Spawn Timer Loop (5s) For Bot Positioning Problem. (Tries Left:%d)", g_iMaxRetries);
#endif
				}
				else
				{
					g_bResetSpawn = true;
					for (new i = 1; i < INFECTED_INDEX_SIZE; i++)
					{
						g_hSpawnTimer[i] = INVALID_HANDLE;
					}
#if _DEBUG
					LogMessage("[+] T_SIC: Resetting Bot Timers Due To No Spawns.");
#endif
				}
			}
		}
	}

	return Plugin_Continue;
}

Sub_InfectedEntitySet(bool:_bReset, bool:_bClearArray)
{
	new _oIsGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	new _oIsAlive = FindSendPropInfo("CTransitioningPlayer", "m_isAlive");
	new _oIsState = FindSendPropInfo("CTerrorPlayer", "m_lifeState");

	if (_bClearArray)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			g_iInfected[INDEX_GHOST][i] = 0;
			g_iInfected[INDEX_DEAD][i] = 0;
			g_iInfected[INDEX_LIFE][i] = 0;
		}
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!_bReset)
		{
			if (IsClientConnected(i) && (!IsFakeClient(i)) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			{
				if (GetEntProp(i,Prop_Send,"m_isGhost") == 1)
				{
					g_iInfected[INDEX_GHOST][i] = 1;
					g_iInfected[INDEX_DEAD][i] = 1;
					SetEntData(i, _oIsGhost, 0, 1, false);
					SetEntData(i, _oIsAlive, 1, 1, true);
				}
				else if (!IsPlayerAlive(i))
				{
					g_iInfected[INDEX_LIFE][i] = 1;
					SetEntData(i, _oIsState, 0, 1, false);
				}
			}
		}
		else
		{
			if (g_iInfected[INDEX_GHOST][i] == 1)
				SetEntData(i, _oIsGhost, 1, 1, true);

			if (g_iInfected[INDEX_DEAD][i] == 1)
				SetEntData(i, _oIsAlive, 0, 1, false);

			if (g_iInfected[INDEX_LIFE][i] == 1)
			{
				SetEntData(i, _oIsState, 1, 1, true);
				g_iInfected[INDEX_LIFE][i] = 0;
			}
		}
	}
}

Sub_CountInfectedClass(bool:_bUpdateGlobals,bool:_bAllClients)
{
	new _iHunterCount = 0;
	new _iSmokerCount = 0;
	new _iBoomerCount = 0;
	new _iSpitterCount = 0;
	new _iChargerCount = 0;
	new _iJockeyCount = 0;
	new _iTankCount = 0;
	new _iInfectedCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (_bAllClients)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			{
				switch (Sub_GetClass(i))
				{
					case INFECTED_HUNTER: _iHunterCount++;
					case INFECTED_SMOKER: _iSmokerCount++;
					case INFECTED_BOOMER: _iBoomerCount++;
					case INFECTED_TANK:   _iTankCount++;
				}
			}
		}
		else
		{
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
			{
				switch (Sub_GetClass(i))
				{
					case INFECTED_HUNTER: _iHunterCount++;
					case INFECTED_SMOKER: _iSmokerCount++;
					case INFECTED_BOOMER: _iBoomerCount++;
					case INFECTED_TANK:   _iTankCount++;
				}
			}
		}
	}

	if (g_iGameMode == GAMEMODE_VERSUS)
		_iInfectedCount = (_iHunterCount + _iSmokerCount + _iBoomerCount + _iSpitterCount + _iChargerCount + _iJockeyCount + _iTankCount);
	else
		_iInfectedCount = (_iHunterCount + _iSmokerCount + _iBoomerCount + _iSpitterCount + _iChargerCount + _iJockeyCount);

	if (_bUpdateGlobals)
	{
		g_iHunterCount = _iHunterCount;
		g_iSmokerCount = _iSmokerCount;
		g_iBoomerCount = _iBoomerCount;
		g_iSpitterCount = _iSpitterCount;
		g_iChargerCount = _iChargerCount;
		g_iJockeyCount = _iJockeyCount;
		g_iTankCount = _iTankCount;
	}

	return _iInfectedCount;
}

public Action:Timer_KickFakeClient(Handle:_hTimer, any:_iClient)
{
	if (IsClientConnected(_iClient) && !IsClientInKickQueue(_iClient) && IsFakeClient(_iClient))
	{
		KickClient(_iClient,"Kicking Fake Client.");
#if _DEBUG
		LogMessage("[+] T_BK: Kicking Fake Client. (Client:%N)", _iClient);
#endif
	}
}

Sub_CreateFakeClient()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			return i;
	}

	new _iClient = CreateFakeClient("FakeClient");

	if (_iClient != 0)
	{
#if _DEBUG
		LogMessage("[+] S_CFC: Creating Fake Client. (Client:%N)", _iClient);
#endif
		return _iClient;
	}
	else
		return 0;
}

Sub_InfectedAliveCount(bool:_Tank)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (_Tank)
			{
				if (IsPlayerAlive(i) && Sub_GetClass(i) == INFECTED_TANK)
					return true;
			}

			else if (IsPlayerAlive(i))
			{
				return true;
			}
		}
	}

	return false;
}

bool:Sub_RealPlayerCount (_iClient)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i != _iClient)
                {
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
                                return true;
		}
	}

        return false;
}

Show_InfectedHud()
{
	if (g_bRoundEnded || g_bMapEnded || !GetConVarBool(g_hBotHudEnabled) || !Sub_InfectedAliveCount(false))
		return;

	decl String:_sBuffer [150];
	new _iClass = 0;
	new _iSpawnTime = 0;
	new _iHealth = 0;
	new Handle:_hInfectedHud;

	_hInfectedHud = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	SetPanelTitle(_hInfectedHud, "(L4D+) Infected Spawns:");
	DrawPanelText(_hInfectedHud, " ");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (IsPlayerAlive(i))
			{
				switch (Sub_GetClass(i))
				{
					case INFECTED_HUNTER:
					{
						_iClass = INFECTED_HUNTER;
						_iHealth = GetClientHealth(i);
						_iSpawnTime = g_iHunter_SpawnTime;
					}
					case INFECTED_SMOKER:
					{
						_iClass = INFECTED_SMOKER;
						_iHealth = GetClientHealth(i);
						_iSpawnTime = g_iSmoker_SpawnTime;
					}
					case INFECTED_BOOMER:
					{
						_iClass = INFECTED_BOOMER;
						_iHealth = GetClientHealth(i);
						_iSpawnTime = g_iBoomer_SpawnTime;
					}
					case INFECTED_TANK:
					{
						_iClass = INFECTED_TANK;
						_iHealth = GetClientHealth(i);
						_iSpawnTime = 0;
					}
				}

				if (IsFakeClient(i))
					Format(_sBuffer, sizeof(_sBuffer), "%s. (HP: %i) - %is+", TEAM_CLASS(_iClass), _iHealth, _iSpawnTime);
				else
					Format(_sBuffer, sizeof(_sBuffer), "%N. (HP: %i) - 15s+", i, _iHealth);

				DrawPanelItem(_hInfectedHud, _sBuffer);
			}
		}
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
		{
			if (GetClientTeam(i) == TEAM_SPECTATORS)
			{
				if ((GetClientMenu(i) == MenuSource_RawPanel) || (GetClientMenu(i) == MenuSource_None))
				{
					SendPanelToClient(_hInfectedHud, i, Menu_InfectedHud, HUD_FREQ);
				}
			}
		}
	}

	CloseHandle(_hInfectedHud);
}

public Menu_InfectedHud(Handle:_hMenu, MenuAction:action, param1, param2)
{
	return;
}

public Action:Timer_ShowInfectedTankHud(Handle:hTimer)
{
        if (g_bRoundEnded || g_bMapEnded || !Sub_InfectedAliveCount(true))
	{
		g_bTankCheckOnce = false;
                return Plugin_Stop;
	}

        decl String:_sBuffer [150];
        new Handle:_hInfectedTankHud;

        _hInfectedTankHud = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
        SetPanelTitle(_hInfectedTankHud, "(L4D+) Infected Tanks:");
        DrawPanelText(_hInfectedTankHud, " ");

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
                {
                        if (IsPlayerAlive(i) && Sub_GetClass(i) == INFECTED_TANK)
                        {
				Format(_sBuffer, sizeof(_sBuffer), "%N. (HP: %i)", i, GetClientHealth(i));
				DrawPanelItem(_hInfectedTankHud, _sBuffer);
			}
		}
	}

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
                {
                        if (GetClientTeam(i) == TEAM_SURVIVORS)
                        {
                                if ((GetClientMenu(i) == MenuSource_RawPanel) || (GetClientMenu(i) == MenuSource_None))
                                {
                                        SendPanelToClient(_hInfectedTankHud, i, Menu_InfectedTankHud, 1);
                                }
                        }
                }
        }

        CloseHandle(_hInfectedTankHud);
	return Plugin_Continue;
}

public Menu_InfectedTankHud(Handle:_hMenu, MenuAction:action, param1, param2)
{
        return;
}

Sub_CheckGameMode()
{
	decl String:_iGameType[16];

	GetConVarString(FindConVar("mp_gamemode"), _iGameType, sizeof(_iGameType));

	if (StrContains(_iGameType, "survival", false) != -1)
		return GAMEMODE_SURVIVAL;

	else if (StrContains(_iGameType, "versus", false) != -1)
		return GAMEMODE_VERSUS;

        else if (StrContains(_iGameType, "teamversus", false) != -1)
                return GAMEMODE_VERSUS;

        else if (StrContains(_iGameType, "scavenge", false) != -1)
                return GAMEMODE_VERSUS;

        else if (StrContains(_iGameType, "teamscavenge", false) != -1)
                return GAMEMODE_VERSUS;

	else if (StrContains(_iGameType, "coop", false) != -1)
		return GAMEMODE_COOP;

        else if (StrContains(_iGameType, "realism", false) != -1)
                return GAMEMODE_COOP;

	else
		return 0;
}

Sub_GetClass(_iClient)
{
	decl String:_iClass[150];

	GetClientModel(_iClient, _iClass, sizeof(_iClass));

	if (StrContains(_iClass, "hulk", false) != -1)
		return INFECTED_TANK;

	else if (StrContains(_iClass, "boomer", false) != -1)
		return INFECTED_BOOMER;

	else if (StrContains(_iClass, "smoker", false) != -1)
		return INFECTED_SMOKER;

	else if (StrContains(_iClass, "hunter", false) != -1)
		return INFECTED_HUNTER;

	else
		return 0;
}

Sub_GetFileAttribute()
{
	decl String:_sMap[64];
	decl String:_sFile[PLATFORM_MAX_PATH];

	g_iKvHunter_SpawnTime = GetConVarInt(g_hDefHunterSpawnTime);
	g_iKvSmoker_SpawnTime = GetConVarInt(g_hDefSmokerSpawnTime);
	g_iKvBoomer_SpawnTime = GetConVarInt(g_hDefBoomerSpawnTime);
	g_iKvSpitter_SpawnTime = 0;
	g_iKvCharger_SpawnTime = 0;
	g_iKvJockey_SpawnTime = 0;


	GetCurrentMap(_sMap, sizeof(_sMap));
	BuildPath(Path_SM, _sFile, sizeof(_sFile), "data/%s", L4D_IS_MAPDATAFILE);
	new Handle:kv = CreateKeyValues("L4D+ Infected Spawns");

	if (FileToKeyValues(kv, _sFile))
	{
		KvRewind(kv);
		KvJumpToKey(kv, _sMap);

		g_iKvHunter_SpawnTime = KvGetNum(kv, "hunter", GetConVarInt(g_hDefHunterSpawnTime));
		g_iKvSmoker_SpawnTime = KvGetNum(kv, "smoker", GetConVarInt(g_hDefSmokerSpawnTime));
		g_iKvBoomer_SpawnTime = KvGetNum(kv, "boomer", GetConVarInt(g_hDefBoomerSpawnTime));
		g_iKvSpitter_SpawnTime = KvGetNum(kv, "spitter", 25);
		g_iKvCharger_SpawnTime = KvGetNum(kv, "charger", 30);
		g_iKvJockey_SpawnTime = KvGetNum(kv, "jockey", 35);
	}
	else
		LogMessage("[+] Error: File %s not found under data directory, using defaults.", L4D_IS_MAPDATAFILE);

	CloseHandle(kv);
}

/*public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	LogMessage("[+] Director has called OnSpawnTank");

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i))
                {
                        decl String:_iClass[100];
                        GetClientModel(i, _iClass, sizeof(_iClass));

                        if (GetClientTeam(i) == 3 && IsFakeClient(i) && (StrContains(_iClass, "hulk", false) == -1))
			{
				LogMessage("[+] Tank found, kicking infected: %N", i);
                                KickClient(i);
			}
                }
        }

	Sub_InfectedSpawnDelay(INFECTED_HUNTER);
	Sub_InfectedSpawnDelay(INFECTED_SMOKER);
	Sub_InfectedSpawnDelay(INFECTED_BOOMER);
}*/

/*
Sub_TankJoined()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			decl String:_iClass[100];
			GetClientModel(i, _iClass, sizeof(_iClass));

			if (GetClientTeam(i) == 3 && IsFakeClient(i) && (StrContains(_iClass, "hulk", false) == -1))
				KickClient(i);
		}
	}
}
*/

stock bool:IsFinalMap()
{
        new String:map[128];
        GetCurrentMap(map, sizeof(map));

        if (
                StrContains(map, "l4d_smalltown05_houseboat") != -1 ||
                StrContains(map, "l4d_hospital05_rooftop") != -1 ||
                StrContains(map, "l4d_airport05_runway") != -1 ||
                StrContains(map, "l4d_farm05_cornfield") != -1 ||
                StrContains(map, "l4d_garage02_lots") != -1 ||
                StrContains(map, "l4d_vs_smalltown05_houseboat") != -1 ||
                StrContains(map, "l4d_vs_hospital05_rooftop") != -1 ||
                StrContains(map, "l4d_vs_airport05_runway") != -1 ||
                StrContains(map, "l4d_vs_farm05_cornfield") != -1)

              return true;

        if (
                StrContains(map, "c1m4_atrium") != -1  ||
                StrContains(map, "c2m5_concert") != -1 ||
                StrContains(map, "c3m4_plantation") != -1 ||
                StrContains(map, "c4m5_milltown_escape") != -1 ||
                StrContains(map, "c5m5_bridge") != -1)

              return true;

        return false;
}

public bool:IsProhibitedMap()
{
        new String:map[128];
        GetCurrentMap(map, sizeof(map));

        if (StrContains(map, "c1m1_hotel") != -1)
	{
		g_iTank_SpawnTime = GetRandomInt(90,180);
		return true;
	}

	if (StrContains(map, "c4m4_milltown") != -1)
	{
		g_iTank_SpawnTime = GetRandomInt(60,120);
		return true;
	}

	if (StrContains(map, "c5m1_waterfront") != -1)
	{
		g_iTank_SpawnTime = GetRandomInt(60,80);
                return true;
	}

        return false;
}

public Action:Timer_KickFakeTank(Handle:hTimer)
{
        decl String:stringclass[32];

        for (new i = 1; i <= MaxClients; i++)
        {
	        if (IsClientConnected(i) && !IsClientInKickQueue(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
	                GetClientModel(i, stringclass, 32);

	                if (StrContains(stringclass, "hulk", false) != -1)
	                        KickClient(i,"Kicking Fake Tank.");
		}
        }
}
