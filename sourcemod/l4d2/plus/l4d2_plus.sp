/**
 * vim: set ts=4 :
 * =============================================================================
 * L4D Plus 2.0-L4D2 by XBetaAlpha
 *
 * Allows a player on the infected team to change their infected class.
 * Complete rewrite based on the Infected Character Select idea by Crimson_Fox.
 *
 * SourceMod (C)2004-2016 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION  "2.0"

public Plugin:myinfo =
{
    name        = "Left 4 Dead +",
    author      = "XBetaAlpha",
    description = "L4D Enhanced",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS	2
#define TEAM_INFECTED	3

#define TEXT_JOCKEY_RELEASE "Press MELEE to jump off your victim.\nOr JUMP to jump while riding survivor."
#define TEXT_SMOKER_RELEASE "You can move using DIRECTIONAL keys.\nPress MELEE to let go of your victim."
#define TEXT_SURVIVOR_CRAWL "Move FORWARD to crawl."
#define TEXT_HUNTER_RELEASE "Press MELEE to jump off your victim."
#define TEXT_LEDGE_RELEASE  "Press CROUCH to let go."
#define TEXT_CHARGER_RELEASE "Press MELEE to let go of your victim."
#define TEXT_PLAYER_DEATH   "You are dead!"
#define TEXT_SURVIVOR_WAIT  "You will be unfrozen when round begins."
#define TEXT_FRIENDLY_FIRE  "Friendly fire disabled until all players leave safe zone."
#define TEXT_BOOMER_HACKS   "Press RELOAD to suicide bomb.\nOr ATTACK to bitch slap."
#define SERVER_VS_HOSTNAME  "The Graveyard † %dv%d VS+ † All 8 Survivors"
#define SERVER_CO_HOSTNAME  "The Graveyard - %dx COOP+"
#define SERVER_SV_HOSTNAME  "The Graveyard - %dx SURVIVAL+"
#define SERVER_RL_HOSTNAME  "The Graveyard - %dx REALISM+"
#define SERVER_SC_HOSTNAME  "The Graveyard - %dx SCAVENGE+"
#define GAMEMODE_COOP	    1
#define GAMEMODE_VERSUS	    2
#define GAMEMODE_SURVIVAL   3
#define GAMEMODE_REALISM	4
#define GAMEMODE_SCAVENGE	5
#define TEAM_TYPE(%1)	    (%1 == 1 ? "Spectators" : (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : "None")))
#define TEAM_CLASS(%1)      (%1 == 0 ? "gambler" : (%1 == 1 ? "producer" : (%1 == 2 ? "coach" : (%1 == 3 ? "mechanic" : (%1 == 4 ? "namvet" : (%1 == 5 ? "teenangst" : (%1 == 6 ? "biker" : (%1 == 7 ? "manager" : "Unknown"))))))))
#define TEAM_NICKS(%1)      (%1 == 0 ? "Pervert" : (%1 == 1 ? "Braniac" : (%1 == 2 ? "Fatman" : (%1 == 3 ? "RedNeck" : (%1 == 4 ? "Bill" : (%1 == 5 ? "Zoey" : (%1 == 6 ? "Francis" : (%1 == 7 ? "Louis" : "Unknown"))))))))
#define WEAPON_CLASS(%1)    (%1 == 1 ? "rifle_sg552" : (%1 == 2 ? "smg_mp5" : (%1 == 3 ? "sniper_awp" : (%1 == 4 ? "sniper_scout" : "Unknown"))))

new Handle:h_fm_r1delay = INVALID_HANDLE;
new Handle:h_fm_r2delay = INVALID_HANDLE;
new Handle:h_nm_r1delay = INVALID_HANDLE;
new Handle:h_nm_r2delay = INVALID_HANDLE;
new Handle:h_r1delay = INVALID_HANDLE;
new Handle:h_r2delay = INVALID_HANDLE;
new Handle:h_RoundTimer = INVALID_HANDLE;
new Handle:g_hSurvivorLimit = INVALID_HANDLE;
new Handle:g_hInfectedLimit = INVALID_HANDLE;
new Handle:h_co_survivor_limit = INVALID_HANDLE;
new Handle:h_co_infected_limit = INVALID_HANDLE;
new Handle:h_vs_survivor_limit = INVALID_HANDLE;
new Handle:h_vs_infected_limit = INVALID_HANDLE;
new Handle:h_sv_survivor_limit = INVALID_HANDLE;
new Handle:h_sv_infected_limit = INVALID_HANDLE;

new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:g_hOnPummelEnded = INVALID_HANDLE;
new Handle:g_hStartActivationTimer = INVALID_HANDLE;
new Handle:g_hPounceEnd = INVALID_HANDLE;
new Handle:g_hSetCharacter = INVALID_HANDLE;

new RoundCounter;
new bool:isFirstRound = false;
new bool:RoundStart = false;
new bool:RoundEnd = false;
new bool:MapEnded = false;
new bool:LeftSafeRoom = false;
new bool:AllLeftSafeRoom = false;
new bool:CheckPointDoorOpened = false;
new bool:FriendlyFire = false;
new bool:g_bAllBotsSpawned = false;
new bool:g_bFinaleHasStarted = false;
new bool:SafeRoomPlayers[MAXPLAYERS+1] = {false,...};
new bool:MedKitPlayers[MAXPLAYERS+1] = {false,...};
new bool:WeaponPlayers[MAXPLAYERS+1] = {false,...};
new bool:g_bWarpEnable[MAXPLAYERS+1] = {false,...};
new bool:g_bChargerPummel = false;
new players[MAXPLAYERS+1];
new Health[MAXPLAYERS+1];
new Float:HangTime[MAXPLAYERS+1];
new bool:g_ButtonDelay[MAXPLAYERS+1] = {false,...};
new g_iMaxSurvivors;
new g_iMedKitCount;
new g_iWeaponCount;
new g_iClassCount;
new g_iBotModelType[MAXPLAYERS+1] = {0,...};

new bool:g_bIsFirstMap = false;

// Smoker Move

new Handle:RangeCheckTimer[MAXPLAYERS+1];
new bool:Grabbed[MAXPLAYERS+1];
new o_mSpeed;
new player_disconnect = 0;

public OnPluginStart()
{
	decl String:ModName[50]; GetGameFolderName(ModName, sizeof(ModName));
	if (!StrEqual(ModName, "left4dead2", false)) SetFailState("This plugin requires Left 4 Dead 2.");

	RegConsoleCmd("sm_warp", Cmd_WarpPlayer);

        HookEvent("tongue_grab",		Event_TongueGrabbed, EventHookMode_Pre);
	HookEvent("jockey_ride",		Event_JockeyRide, EventHookMode_Pre);
        HookEvent("tongue_release",		Event_TongueRelease, EventHookMode_Pre);
        HookEvent("lunge_pounce",		Event_HunterPounced);
        HookEvent("pounce_end",                 Event_PounceEnd);
	HookEvent("charger_pummel_start",	Event_ChargerPummelStart);
        HookEvent("finale_vehicle_leaving",	Event_FinaleVehicleLeaving, EventHookMode_PostNoCopy);
	HookEvent("finale_win",			Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_hurt", 		Event_PlayerHurt, EventHookMode_Pre);
        HookEvent("player_spawn",		Event_PlayerSpawn, EventHookMode_Post);
        HookEvent("player_incapacitated",	Event_PlayerIncapped);
	HookEvent("player_left_start_area",	Event_PlayerLeftStartArea);
        HookEvent("player_ledge_grab",          Event_PlayerLedgeGrab);
        HookEvent("player_left_checkpoint",	Event_PlayerLeftCheckPoint, EventHookMode_Pre);
	HookEvent("door_open",			Event_DoorOpen);
        HookEvent("round_start",		Event_RoundStart, EventHookMode_Pre);
        HookEvent("round_end",			Event_RoundEnd, EventHookMode_Pre);
        HookEvent("mission_lost",		Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_bot_replace",		Event_PlayerBotReplace);
	HookEvent("bot_player_replace",		Event_BotPlayerReplace);
	HookEvent("finale_start",		Event_FinaleStart);

	CreateConVar("l4dplus_version", PLUGIN_VERSION, "L4D+", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	h_fm_r1delay = CreateConVar("l4dp_fm_r1delay", "25", "Delay timer for first round (firstmap).");
        h_fm_r2delay = CreateConVar("l4dp_fm_r2delay", "20", "Delay timer for second round (firstmap).");
	h_nm_r1delay = CreateConVar("l4dp_nm_r1delay", "15", "Delay timer for first round (nextmap).");
	h_nm_r2delay = CreateConVar("l4dp_nm_r2delay", "10", "Delay timer for second round (nextmap).");

	h_co_survivor_limit = CreateConVar("l4dp_survivor_limit_coop", "4", "COOP Survivor Limit.");
	h_co_infected_limit = CreateConVar("l4dp_infected_limit_coop", "4", "COOP Infected Limit.");
	h_vs_survivor_limit = CreateConVar("l4dp_survivor_limit_vs", "4", "VS Survivor Limit.");
	h_vs_infected_limit = CreateConVar("l4dp_infected_limit_vs", "4", "VS Infected Limit.");
	h_sv_survivor_limit = CreateConVar("l4dp_survivor_limit_sv", "4", "Survival Survivor Limit.");
	h_sv_infected_limit = CreateConVar("l4dp_infected_limit_sv", "0", "Survival Infected Limit.");

	g_hSurvivorLimit = FindConVar("survivor_limit");
	g_hInfectedLimit = FindConVar("z_max_player_zombies");

	o_mSpeed = FindSendPropInfo("CTerrorPlayer","m_flLaggedMovementValue");

        AutoExecConfig(true, "l4d2_plus");

        g_hGameConf = LoadGameConfigFile("l4d2_plus");

        if (g_hGameConf != INVALID_HANDLE)
        {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded");
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
		g_hOnPummelEnded = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CBaseAbility::StartActivationTimer");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hStartActivationTimer = EndPrepSDKCall();

                StartPrepSDKCall(SDKCall_Entity);
                PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer::OnPounceEnd");
                g_hPounceEnd = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer::SetCharacter");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetCharacter = EndPrepSDKCall();
	}

	Sub_FilterCvar("sv_steamgroup");
	Sub_FilterCvar("sv_alltalk");
	Sub_FilterCvar("sv_cheats");
	Sub_FilterCvar("buddha");
	Sub_FilterCvar("coop");
	Sub_FilterCvar("deathmatch");
	Sub_FilterCvar("decalfrequency");
	Sub_FilterCvar("director_afk_timeout");
	Sub_FilterCvar("tv_enable");
	Sub_FilterCvar("tv_password");
	Sub_FilterCvar("tv_relaypassword");
}

Sub_GameSetup()
{
        decl String:linebuf[1024];
        switch (CheckGameMode()) {
                case GAMEMODE_COOP: {
                        Format(linebuf, sizeof(linebuf), SERVER_CO_HOSTNAME, GetConVarInt(h_co_survivor_limit));
                        SetConVarString(FindConVar("hostname"), linebuf);
                        Sub_ChangePlayerCount(GetConVarInt(h_co_survivor_limit),GetConVarInt(h_co_infected_limit));
                        SetConVarInt(FindConVar("sv_alltalk"), 1);
                        ServerCommand("exec server/coop-set.cfg");
                        ServerCommand("sm plugins unload l4d2_team");
			ServerCommand("sm plugins unload l4d2_is");
                }

                case GAMEMODE_VERSUS: {
			//new PlayerCount = Sub_GetPlayerCount();
			//new MaxPlayerCount = GetConVarInt(h_vs_survivor_limit) + GetConVarInt(h_vs_infected_limit);
                        Format(linebuf, sizeof(linebuf), SERVER_VS_HOSTNAME, GetConVarInt(h_vs_survivor_limit), GetConVarInt(h_vs_infected_limit));
                        SetConVarString(FindConVar("hostname"), linebuf);
                        Sub_ChangePlayerCount(GetConVarInt(h_vs_survivor_limit), GetConVarInt(h_vs_infected_limit));
			//ServerCommand("exec server/versus-init.cfg");
                }

                case GAMEMODE_SURVIVAL: {
                        Format(linebuf, sizeof(linebuf), SERVER_SV_HOSTNAME, GetConVarInt(h_sv_survivor_limit));
                        SetConVarString(FindConVar("hostname"), linebuf);
                        Sub_ChangePlayerCount(GetConVarInt(h_sv_survivor_limit),GetConVarInt(h_sv_infected_limit));
                        SetConVarInt(FindConVar("sv_alltalk"), 1);
                        VersusOnlyChangeSettings(false);
                        CoopAndVersusChangeSettings(false);
                        ServerCommand("sm plugins unload l4d2_team");
                        ServerCommand("sm plugins unload l4d2_mapchanger");
			ServerCommand("sm plugins unload l4d2_is");
                }

		case GAMEMODE_REALISM: {
			Format(linebuf, sizeof(linebuf), SERVER_RL_HOSTNAME, GetConVarInt(h_co_survivor_limit));
			SetConVarString(FindConVar("hostname"), linebuf);
			Sub_ChangePlayerCount(GetConVarInt(h_co_survivor_limit),GetConVarInt(h_co_infected_limit));
			SetConVarInt(FindConVar("sv_alltalk"), 1);
			VersusOnlyChangeSettings(false);
			CoopAndVersusChangeSettings(false);
			ServerCommand("sm plugins unload l4d2_team");
			ServerCommand("sm plugins unload l4d2_is");
			ServerCommand("sm plugins unload l4d2_mapchanger");
		}

		case GAMEMODE_SCAVENGE: {
                        Format(linebuf, sizeof(linebuf), SERVER_SC_HOSTNAME, GetConVarInt(h_vs_survivor_limit),GetConVarInt(h_vs_infected_limit));
                        SetConVarString(FindConVar("hostname"), linebuf);
                        Sub_ChangePlayerCount(GetConVarInt(h_vs_survivor_limit),GetConVarInt(h_vs_infected_limit));
                        VersusOnlyChangeSettings(true);
                        CoopAndVersusChangeSettings(true);
			ServerCommand("sm plugins unload l4d2_is");
			ServerCommand("sm plugins unload l4d2_mapchanger");
                }
	}

	g_iMaxSurvivors = GetConVarInt(FindConVar("survivor_limit"));
}

public OnMapStart()
{
        isFirstRound = true;
        MapEnded = false;
}

Sub_Precache(bool:Object, String:FileName[])
{
	if (Object)
	{
		if (!IsModelPrecached(FileName))
		{
			PrecacheModel(FileName);
		}
	}

	else
	{
		if (!IsSoundPrecached(FileName))
		{
			PrecacheSound(FileName);
		}
	}
}

Sub_CheckRoundDelay()
{
        decl String:current_map[64];
        GetCurrentMap(current_map, sizeof(current_map));

        if (StrContains(current_map, "01") == -1)
	{
		h_r1delay = h_nm_r1delay;
		h_r2delay = h_nm_r2delay;

		if (StrContains(current_map, "m1_") == -1) {
			g_bIsFirstMap = false;
			h_r1delay = h_nm_r1delay;
			h_r2delay = h_nm_r2delay;
		}
		else
		{
			g_bIsFirstMap = true;
	                h_r1delay = h_fm_r1delay;
	                h_r2delay = h_fm_r2delay;
		}
        }
	else
	{
            	h_r1delay = h_fm_r1delay;
        	h_r2delay = h_fm_r2delay;
        }
}

public OnMapEnd()
{
        isFirstRound = true;
	MapEnded = true;
        RoundStart = false;
        RoundEnd = true;
	g_bAllBotsSpawned = false;

	LogMessage("[+] OME: Map Has Ended.");
        if (h_RoundTimer != INVALID_HANDLE) h_RoundTimer = INVALID_HANDLE;
}

public OnClientPutInServer(client)
{
	if (IsFakeClient(client))
		return;

	//Sub_SetTimeOut(client);
}

public bool:OnClientConnect(client, String: rejectmsg[], maxlen)
{
        if (client && !IsFakeClient(client))
        {
		//CreateTimer(1.0, Timer_CheckPlayerCounts, _, TIMER_FLAG_NO_MAPCHANGE);

		if (LeftSafeRoom)
		{
			LogMessage("[+] OCC: Sending Heartbeat. (On ClientConnect)");
			ServerCommand("heartbeat");
		}
        }

        return true;
}

public OnClientDisconnect(client)
{
	if (!LeftSafeRoom)
	        SafeRoomPlayers[client] = false;

	if (IsFakeClient(client))
		return;

	if (RoundStart)
	{
		LogMessage("[+] OCD: Sending Heartbeat. (On ClientDisconnect)");
		ServerCommand("heartbeat");
	}

	//CreateTimer(1.0, Timer_CheckPlayerCounts, _, TIMER_FLAG_NO_MAPCHANGE);

	player_disconnect = client;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (RoundStart)	return;

	g_bFinaleHasStarted = false;
	FriendlyFire = true;
	g_iMedKitCount = 0;
	g_iWeaponCount = 0;
	g_iClassCount = 0;
	RoundStart = true;
	RoundEnd = false;
	LeftSafeRoom = false;
	AllLeftSafeRoom = false;
	CheckPointDoorOpened = false;
	RoundCounter = 0;
	player_disconnect = 0;

	if (isFirstRound)
	{
		LogMessage("[+] Map Start Round 1: Initialising Cvar's/Precache/Players.");

	        ServerCommand("exec server/versus-init.cfg");

        	Sub_Precache(false,"ui/beep07.wav");
 	        Sub_Precache(false,"ui/survival_teamrec.wav");

        	Sub_Precache(true,"models/survivors/survivor_teenangst.mdl");
        	Sub_Precache(true,"models/survivors/survivor_biker.mdl");
        	Sub_Precache(true,"models/survivors/survivor_manager.mdl");
        	Sub_Precache(true,"models/survivors/survivor_namvet.mdl");
        	Sub_Precache(true,"models/survivors/survivor_gambler.mdl");
        	Sub_Precache(true,"models/survivors/survivor_coach.mdl");
        	Sub_Precache(true,"models/survivors/survivor_mechanic.mdl");
        	Sub_Precache(true,"models/survivors/survivor_producer.mdl");
	}

	Sub_GameSetup();

	if (CheckGameMode() == GAMEMODE_SURVIVAL)
	{
		FriendlyFire = false;
		return;
	}

	if (FriendlyFire)
		FriendlyFireChangeSettings(true);
	else
		FriendlyFireChangeSettings(false);

	CreateTimer(0.1, Timer_AddSurvivor, _, TIMER_REPEAT);

     	for (new i = 1; i <= MaxClients; i++)
	{
		g_iBotModelType[i] = 0;
		SafeRoomPlayers[i] = false;
		MedKitPlayers[i] = false;
		WeaponPlayers[i] = false;
                Health[i] = 0;
                HangTime[i] = 0.0;
                g_ButtonDelay[i] = false;

		CreateTimer(0.5, Timer_AddMedKit, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        	CreateTimer(0.5, Timer_AddWeapons, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	if (h_RoundTimer == INVALID_HANDLE)
		h_RoundTimer = CreateTimer(1.0, RoundTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

	SetConVarInt(FindConVar("sb_unstick"), 0);
	SetConVarInt(FindConVar("sb_move"), 0);

	Sub_CheckRoundDelay();
	Sub_CheckpointDoorControl(true);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (RoundEnd) return;

        isFirstRound = false;
	RoundStart = false;
	RoundEnd = true;
	LeftSafeRoom = false;
	AllLeftSafeRoom = false;
	CheckPointDoorOpened = false;
	RoundCounter = 0;
	g_bAllBotsSpawned = false;

	LogMessage("[+] E_RE: Round Has Ended.");

        if (h_RoundTimer != INVALID_HANDLE) h_RoundTimer = INVALID_HANDLE;
}

public Action:Event_TongueGrabbed(Handle:event, const String:name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client))
		return Plugin_Continue;

	new victim = GetClientOfUserId(GetEventInt(event, "victim"));

        players[victim] = 1;

	PrintHintText(client, TEXT_SMOKER_RELEASE);

	new Handle:pack;
	Grabbed[client] = true;

	SetEntityMoveType(client, MOVETYPE_ISOMETRIC);
	SetEntDataFloat(client, o_mSpeed, 0.15, true);

	RangeCheckTimer[client] = CreateDataTimer(0.2, RangeCheckTimerFunction, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

	WritePackCell(pack, client);
	WritePackCell(pack, victim);

	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
        if (MapEnded || RoundEnd)
		return Plugin_Continue;

	if (!LeftSafeRoom)
                return Plugin_Continue;

        new client = GetClientOfUserId(GetEventInt(event, "userid"));

        if (IsFakeClient(client) || !IsValidEntity(client) || GetClientTeam(client) != TEAM_INFECTED)
                return Plugin_Continue;

	new ZClass = GetEntProp(client, Prop_Send, "m_zombieClass");

	if (ZClass == 2)
		PrintHintText(client, TEXT_BOOMER_HACKS);

	return Plugin_Continue;
}

public Event_JockeyRide(Handle:event, const String:name[], bool:dontBroadcast)
{
        new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(Client))
		return;

        PrintHintText(Client, TEXT_JOCKEY_RELEASE);
}

public Event_HunterPounced(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(Client))
		return;

	PrintHintText(Client, TEXT_HUNTER_RELEASE);
}

public Event_ChargerPummelStart(Handle:event, const String:name[], bool:dontBroadcast)
{
        new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(Client))
		return;

        if (!g_bChargerPummel)
                g_bChargerPummel = true;

        PrintHintText(Client, TEXT_CHARGER_RELEASE);
}

public Action:Event_PlayerIncapped(Handle:event, const String:name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client))
		return;

	if (GetConVarInt(FindConVar("survivor_allow_crawling")) == 1)
	{
	        if (players[client] != 1)
		{
			if (GetClientTeam(client) == TEAM_SURVIVORS)
			{
				if (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || !g_bChargerPummel)
					if (GetClientHealth(client) > 1)
						PrintHintText(client, TEXT_SURVIVOR_CRAWL);
			}
		}
	}
}

public Action:Event_TongueRelease(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));

	if (GetConVarInt(FindConVar("survivor_allow_crawling")) == 1)
	{
	        if (victim > 0 && !IsFakeClient(victim))
		{
		        players[victim] = 0;
	                if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
			{
	                        if (!GetEntProp(victim, Prop_Send, "m_isHangingFromLedge") || !g_bChargerPummel)
				{
					if (GetClientHealth(victim) > 1)
						PrintHintText(victim, TEXT_SURVIVOR_CRAWL);
				}
			}
		}
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0 || IsFakeClient(client))
		return Plugin_Continue;

	Grabbed[client] = false;
	SetEntityMoveType(client, MOVETYPE_CUSTOM);
	SetEntDataFloat(client, o_mSpeed, 1.0, true);

	if (RangeCheckTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(RangeCheckTimer[client]);
		RangeCheckTimer[client] = INVALID_HANDLE;
	}

	return Plugin_Continue;
}

public Action:Event_PounceEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));

        if (GetConVarInt(FindConVar("survivor_allow_crawling")) == 1)
	{
                if (victim > 0 && !IsFakeClient(victim))
		{
                        players[victim] = 0;
                        if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
			{
                                if (!GetEntProp(victim, Prop_Send, "m_isHangingFromLedge") || !g_bChargerPummel)
                                        if (GetClientHealth(victim) > 1)
                                                PrintHintText(victim, TEXT_SURVIVOR_CRAWL);
			}
                }
        }
}

public Action:Event_PlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));

	if (bot == 0 || MapEnded)
		return Plugin_Continue;

        if (!IsClientInGame(bot))
                return Plugin_Continue;

	if (GetClientTeam(bot) != TEAM_SURVIVORS)
                return Plugin_Continue;

	decl String:sbModel[255];
	GetClientModel(bot, sbModel, sizeof(sbModel));

	//LogMessage("[+] E_PBR: Bot (%N, %i) Replaced Player (%N) Model: %s", bot, bot, player == 0 ? 0 : player, sbModel);

	if (player == 0)
	{
		//LogMessage("[+] E_PBR: Player has disconnected! (Client ID was: %i, Bot Event: %i, Bot Type: %i)", player_disconnect, bot, g_iBotModelType[player_disconnect]);
		SDKCall(g_hSetCharacter, bot, g_iBotModelType[player_disconnect]);
		Format(sbModel, sizeof(sbModel), "models/survivors/survivor_%s.mdl", TEAM_CLASS(g_iBotModelType[player_disconnect]));
	}

	else
        {

                SDKCall(g_hSetCharacter, bot, g_iBotModelType[player]);
                Format(sbModel, sizeof(sbModel), "models/survivors/survivor_%s.mdl", TEAM_CLASS(g_iBotModelType[player]));
        }

	SetEntityModel(bot, sbModel);

	return Plugin_Continue;
}

public Action:Event_BotPlayerReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));

        if (player == 0 || bot == 0 || MapEnded)
                return Plugin_Continue;

	if (!IsClientInGame(player))
		return Plugin_Continue;

	if(GetClientTeam(player) != TEAM_SURVIVORS)
		return Plugin_Continue;

	//LogMessage("[+] E_BPR: Player (%N) Replaced Bot (%N)", player, bot);

        decl String:spModel[255];
        decl String:sbModel[255];

        GetClientModel(player, spModel, sizeof(spModel));
        GetClientModel(bot, sbModel, sizeof(sbModel));

        if (StrContains(sbModel, "gambler") != -1)
		g_iBotModelType[player] = 0;

        else if (StrContains(sbModel, "producer") != -1)
                g_iBotModelType[player] = 1;

        else if (StrContains(sbModel, "coach") != -1)
                g_iBotModelType[player] = 2;

        else if (StrContains(sbModel, "mechanic") != -1)
                g_iBotModelType[player] = 3;

        else if (StrContains(sbModel, "namvet") != -1)
                g_iBotModelType[player] = 4;

        else if (StrContains(sbModel, "teenangst") != -1)
                g_iBotModelType[player] = 5;

        else if (StrContains(sbModel, "biker") != -1)
                g_iBotModelType[player] = 6;

        else if (StrContains(sbModel, "manager") != -1)
		g_iBotModelType[player] = 7;

	SDKCall(g_hSetCharacter, player, g_iBotModelType[player]);
	//SetEntProp(player, Prop_Send, "m_survivorCharacter", g_iBotModelType[player]);
	Format(spModel, sizeof(spModel), "models/survivors/survivor_%s.mdl", TEAM_CLASS(g_iBotModelType[player]));
	SetEntityModel(player, spModel);

	return Plugin_Continue;
}

public Action:Timer_CheckPlayerCounts(Handle:hTimer)
{
        decl String:linebuf[1024];
        new PlayerCount = Sub_GetPlayerCount();
        new MaxPlayerCount = GetConVarInt(h_vs_survivor_limit) + GetConVarInt(h_vs_infected_limit);
        Format(linebuf, sizeof(linebuf), SERVER_VS_HOSTNAME, PlayerCount, MaxPlayerCount, GetConVarInt(h_vs_survivor_limit), GetConVarInt(h_vs_infected_limit));
        SetConVarString(FindConVar("hostname"), linebuf);

	return Plugin_Continue;
}

public Action:Timer_AddWeapons(Handle:hTimer, any:client)
{
        if (g_iWeaponCount >= g_iMaxSurvivors)
                return Plugin_Stop;

	if (!g_bAllBotsSpawned)
		return Plugin_Continue;

	if (client != 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		new _iWeaponClass = GetRandomInt(1,3);
		SetCommandFlags("give", GetCommandFlags("give") & ~FCVAR_CHEAT);
		FakeClientCommand(client, "give %s", WEAPON_CLASS(_iWeaponClass));
		FakeClientCommand(client, "give pistol");
		SetEntityHealth(client, 125);
		//LogMessage("[+] T_AMK: Setting Health for Survivor: %N (125)", client);
		//LogMessage("[+] T_AMK: Giving Weapon (%s) to Survivor: %N (%i)", WEAPON_CLASS(_iWeaponClass), client, client);
		SetCommandFlags("give", GetCommandFlags("give")|FCVAR_CHEAT);
		g_iWeaponCount++;
	}

        return Plugin_Continue;
}

public Action:Timer_AddSurvivor(Handle:hTimer)
{
        if (MapEnded || RoundEnd || g_bAllBotsSpawned)
                return Plugin_Continue;

	new _iNumSurvivors = Sub_CountTeam(TEAM_SURVIVORS, false);

	decl String:current_map[64];
	GetCurrentMap(current_map, sizeof(current_map));

       	if (_iNumSurvivors >= g_iMaxSurvivors)
	{
		LogMessage("[+] T_SBT: Survivors team at maximum. (%d/%d)", _iNumSurvivors, g_iMaxSurvivors);
		g_bAllBotsSpawned = true;

		g_iClassCount = 0;
		decl String:Model[64];

	        for (new i = 1; i <= MaxClients; i++)
	        {
	                if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
	                {
                                if (g_iClassCount == 8)
                                {
                                        g_iClassCount = 0;
                                }

				//LogMessage("[+] S_SBT: Changing Survivor Model: %N -> %s", i, TEAM_CLASS(g_iClassCount));
				SDKCall(g_hSetCharacter, i, g_iClassCount);
				//SetEntProp(i, Prop_Send, "m_survivorCharacter", g_iClassCount);
				Format(Model, sizeof(Model), "models/survivors/survivor_%s.mdl", TEAM_CLASS(g_iClassCount));
				SetEntityModel(i, Model);
				g_iBotModelType[i] = g_iClassCount;
				g_iClassCount++;
	                }
	        }

		return Plugin_Stop;
	}

	if (g_iClassCount > 3) g_iClassCount = 0;

	ServerCommand("sb_add %s", TEAM_CLASS(g_iClassCount));
	//LogMessage("[+] S_SBT: Adding extra Survivor: %s", TEAM_CLASS(g_iClassCount));
	g_iClassCount++;

/*
	new Bot = CreateFakeClient("SurvivorBot");
	if (Bot != 0)
	{
		ChangeClientTeam(Bot, TEAM_SURVIVORS);

		if (DispatchKeyValue(Bot, "classname", "SurvivorBot") == false)
		{
			LogMessage("[+] T_SBT: Failed to set bot's classname.");
			return Plugin_Continue;
		}

		if (DispatchSpawn(Bot) == false)
		{
			LogMessage("[+] T_SBT: Failed to spawn bot.");
			return Plugin_Continue;
		}

		if (g_iClassCount > 3) g_iClassCount = 0;

		LogMessage("[+] S_SBT: Adding extra Survivor (%d): %s", _iNumSurvivors+1, TEAM_CLASS(g_iClassCount));

		//SDKCall(g_hSetCharacter, Bot, g_iClassCount);
		//SetEntProp(Bot, Prop_Send, "m_survivorCharacter", g_iClassCount);
		//decl String:Model[64];
		//Format(Model, sizeof(Model), "models/survivors/survivor_%s.mdl", TEAM_CLASS(g_iClassCount));
		//SetEntityModel(Bot, Model);

		CreateTimer(0.1, KickFakeClient, Bot);

                g_iClassCount++;
	}

	else
	{
		LogMessage("[+] S_SBT: Failed to create fake client.");
		return Plugin_Continue;
	}
*/
        return Plugin_Continue;
}

public Action:Timer_AddMedKit(Handle:hTimer, any:client)
{
        if (g_iMedKitCount >= (g_iMaxSurvivors-4))
                return Plugin_Stop;

	if (!g_bAllBotsSpawned)
		return Plugin_Continue;

	if (client != 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		if (!MedKitPlayers[client])
		{
			SetCommandFlags("give", GetCommandFlags("give") & ~FCVAR_CHEAT);
			FakeClientCommand(client, "give first_aid_kit");
			SetCommandFlags("give", GetCommandFlags("give")|FCVAR_CHEAT);
			//LogMessage("[+] T_AMK: Giving medkit to Survivor: %N (%i)", client, client);
			g_iMedKitCount++;
			MedKitPlayers[client] = true;
		}
	}

	return Plugin_Continue;
}

public Event_FinaleVehicleLeaving(Handle:hEvent, const String:StrName[], bool:DontBroadcast)
{
	new edict_index = FindEntityByClassname(-1, "info_survivor_position");

	if (edict_index != -1)
	{
		new Float:Pos[3];
		GetEntPropVector(edict_index, Prop_Send, "m_vecOrigin", Pos);
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i))
		 		continue;
			if (!IsClientInGame(i))
		            	continue;
			if (GetClientTeam(i) != TEAM_SURVIVORS)
				continue;
			if (!IsPlayerAlive(i))
				continue;
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) == 1)
				continue;

			TeleportEntity(i, Pos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
        if (AllLeftSafeRoom || !FriendlyFire)
                return Plugin_Continue;

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (victim != 0 && attacker != 0) {
		if (!AllLeftSafeRoom)
		{
			if (GetClientTeam(victim) == TEAM_SURVIVORS && GetClientTeam(attacker) == TEAM_SURVIVORS)
			{
				if (g_bIsFirstMap && RoundCounter == -1)
					PrintHintText(attacker, TEXT_FRIENDLY_FIRE);
				else
					PrintHintText(attacker, TEXT_FRIENDLY_FIRE);

				return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!LeftSafeRoom) {
		if (FriendlyFire) {
	        	new client = GetClientOfUserId(GetEventInt(event, "userid"));
			if (client != 0 && GetClientTeam(client) == TEAM_SURVIVORS) {
                    		CheckPointDoorOpened = true;
				if (!SafeRoomPlayers[client])
				{
                                	SafeRoomPlayers[client] = true;
                                	//LogMessage("[+] E_PLSA: Safe Zone Player Left: %N (%i)", client, client);
				}
			}
		}
		LeftSafeRoom = true;
	}
        return Plugin_Continue;
}

public Action:Event_DoorOpen(Handle:event, const String:name[], bool:dontBroadcast)
{
        if (!LeftSafeRoom) {
                if (GetEventBool(event, "checkpoint")) {
			CheckPointDoorOpened = true;
                }
        }
        return Plugin_Continue;
}

public Action:Event_PlayerLeftCheckPoint(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!AllLeftSafeRoom) {
      		new client = GetClientOfUserId(GetEventInt(event, "userid"));
	        if (CheckPointDoorOpened) {
			if (FriendlyFire) {
				if (client != 0 && GetClientTeam(client) == TEAM_SURVIVORS) {
					if (!SafeRoomPlayers[client])
					{
						SafeRoomPlayers[client] = true;
						//LogMessage("[+] E_PLCP: Safe Zone Player Left: %N (%i)", client, client);
					}
				}
				if (SurvivorsLeftCheckPoint() >= GetTeamClientCount(TEAM_SURVIVORS)) {
					AllLeftSafeRoom = true;
					FriendlyFireChangeSettings(false);
			        	LogMessage("[+] E_PLCP: Safe Zone Players Left: (Friendly Fire Enabled). (%i)", SurvivorsLeftCheckPoint());
					ResetConVar(FindConVar("sb_unstick"));
				}
			}
		}
	}
        return Plugin_Continue;
}

SurvivorsLeftCheckPoint()
{
	new SurvivorsCount = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (SafeRoomPlayers[i] == true)
			SurvivorsCount++;
	}
	return SurvivorsCount;
}

public Action:Event_PlayerLedgeGrab(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	PrintHintText(client, TEXT_LEDGE_RELEASE);
}

Sub_CountTeam(any:_iTeam, bool:_bFake)
{
	new _iCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			if (!_bFake)
			{
				if (GetClientTeam(i) == _iTeam)
					_iCount++;
			}
			else
			{
				if (IsFakeClient(i) && GetClientTeam(i) == _iTeam)
					_iCount++;
			}
                }
        }

	return _iCount;
}

public Action:RoundTimer(Handle:timer)
{
	if (!g_bAllBotsSpawned)
		return Plugin_Continue;

        if (RoundCounter == -1 || RoundEnd)
	{
		h_RoundTimer = INVALID_HANDLE;
                return Plugin_Stop;
	}
	else

        if (RoundCounter++ >= GetConVarInt(isFirstRound ? h_r1delay : h_r2delay) - 1)
	{
                RoundCounter = -1;

                for (new i = 1; i <= MaxClients; i++)
		{
                        DrawRoundStartHud(i);
                }

		h_RoundTimer = INVALID_HANDLE;

                Sub_CheckpointDoorControl(false);

        	ResetConVar(FindConVar("sb_move"));
		EmitSoundToAll("ui/survival_teamrec.wav");

                return Plugin_Stop;
        }

	else
	{
                for (new i = 1; i <= MaxClients; i++)
		{
                        DrawRoundWaitHud(i);
		}

		if (RoundCounter > (GetConVarInt(isFirstRound ? h_r1delay : h_r2delay) - 7))
			EmitSoundToAll("ui/beep07.wav");
	}

        return Plugin_Continue;
}

DrawRoundWaitHud(client)
{
	if (!IsClientInGame(client))
		return;

        decl String:linebuf[1024];
        new Handle:panel = CreatePanel();

        Format(linebuf, sizeof(linebuf), "%s. Round %d will start in %ds.", g_bIsFirstMap ? "Versus Match" : "Get Ready", isFirstRound ? 1 : 2, GetConVarInt(isFirstRound ? h_r1delay : h_r2delay) - RoundCounter);
        DrawPanelText(panel, linebuf);
        SendPanelToClient(panel, client, Text_Hud, GetConVarInt(isFirstRound ? h_r1delay : h_r2delay) - RoundCounter);
        CloseHandle(panel);
}

DrawRoundStartHud(client)
{
	if (!IsClientInGame(client))
		return;

	decl String:linebuf[1024];
        new Handle:panel = CreatePanel();

	Format(linebuf, sizeof(linebuf), "Round %d Started.", isFirstRound ? 1 : 2);
        DrawPanelText(panel, linebuf);
        SendPanelToClient(panel, client, Text_Hud, 10);
        CloseHandle(panel);
}

public Text_Hud(Handle:menu, MenuAction:action, param1, param2)
{
        return;
}

CheckGameMode()
{
        new String:GameName[16];
        GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));

	if (StrContains(GameName, "scavenge", false) != -1)
		return 2;
	else if (StrContains(GameName, "teamscavenge", false) != -1)
                return 2;
	else if (StrContains(GameName, "realism", false) != -1)
		return 1;
        else if (StrContains(GameName, "survival", false) != -1)
                return 3;
        else if (StrContains(GameName, "versus", false) != -1)
                return 2;
        else if (StrContains(GameName, "teamversus", false) != -1)
                return 2;
	else if (StrContains(GameName, "mutation12", false) != -1)
		return 2;
        else if (StrContains(GameName, "coop", false) != -1)
                return 1;
	else
		return 0;
}

public Sub_ChangePlayerCount(any:SurvivorCount, any:InfectedCount)
{
	new MaxPlayers;
	new GameMode = CheckGameMode();

	SetConVarBounds(g_hSurvivorLimit, ConVarBound_Upper, true, 32.0);
	SetConVarBounds(g_hInfectedLimit, ConVarBound_Upper, true, 32.0);

	if (SurvivorCount > 0 && (SurvivorCount != GetConVarInt(g_hSurvivorLimit)))
	{
		LogMessage("[+] S_CPC: Setting Survivor Limit to: %d", SurvivorCount);
        	SetConVarInt(g_hSurvivorLimit, SurvivorCount);
	}

	if (InfectedCount > 0 && (InfectedCount != GetConVarInt(g_hInfectedLimit)))
	{
		LogMessage("[+] S_CPC: Setting Infected Limit to: %d", InfectedCount);
		SetConVarInt(g_hInfectedLimit, InfectedCount);
	}

	if (GameMode == GAMEMODE_VERSUS || GameMode == GAMEMODE_SCAVENGE)
		MaxPlayers = SurvivorCount + InfectedCount;
	else
		MaxPlayers = SurvivorCount;

	if (GetConVarInt(FindConVar("sv_maxplayers")) != MaxPlayers)
	{
		SetConVarInt(FindConVar("sv_maxplayers"), MaxPlayers);
		LogMessage("[+] S_CPC: Maxplayers (sv_maxplayers) set to: %d", MaxPlayers);
	}
}

stock bool:CheckPlayersInGame(client)
{
        for (new i = 1; i <= MaxClients; i++) {
                if (i != client) {
                        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
                                return true;
                }
        }
        return false;
}

Sub_GetPlayerCount()
{
	new Count = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			Count++;
	}

	return Count;
}

public Action:KickFakeClient(Handle:hTimer, any:Client)
{
	if (!IsClientConnected(Client) || !IsFakeClient(Client))
		return Plugin_Stop;

	KickClient(Client, "Killing bot - Freeing slot.");
	return Plugin_Stop;
}

VersusOnlyChangeSettings(bool:change)
{
	if (change)
	{
		ServerCommand("exec server/versus-init.cfg");
	}
	else
	{
                ServerCommand("exec server/versus-unset.cfg");
	}
}

CoopAndVersusChangeSettings(bool:change)
{
        if (change)
	{
		ServerCommand("exec server/coop-set.cfg");
	}
	else
	{
		ServerCommand("exec server/coop-unset.cfg");
	}
}

FriendlyFireChangeSettings(bool:change)
{
	if (change) {
		SetConVarFloat(FindConVar("survivor_friendly_fire_factor_expert"), 0.0);
		SetConVarFloat(FindConVar("survivor_friendly_fire_factor_hard"),   0.0);
		SetConVarFloat(FindConVar("survivor_friendly_fire_factor_normal"), 0.0);
		SetConVarFloat(FindConVar("survivor_friendly_fire_factor_easy"),   0.0);
		SetConVarFloat(FindConVar("inferno_damage"), 			   0.0);
	}
	else {
                ResetConVar(FindConVar("survivor_friendly_fire_factor_expert"), true, true);
                ResetConVar(FindConVar("survivor_friendly_fire_factor_hard"),	true, true);
                ResetConVar(FindConVar("survivor_friendly_fire_factor_normal"),	true, true);
                ResetConVar(FindConVar("survivor_friendly_fire_factor_easy"),	true, true);
		ResetConVar(FindConVar("inferno_damage"),			true, true);
	}
}

public Action:RangeCheckTimerFunction(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new Smoker = ReadPackCell(pack);
	if ((!IsValidClient(Smoker))||(GetClientTeam(Smoker)!=3)||(IsFakeClient(Smoker))||(Grabbed[Smoker] = false))
	{
		RangeCheckTimer[Smoker] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	new Victim = ReadPackCell(pack);
	if ((!IsValidClient(Victim))||(GetClientTeam(Victim)!=2)||(Grabbed[Smoker] = false))
	{
		RangeCheckTimer[Smoker] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	new Float:SmokerPosition[3];
	new Float:VictimPosition[3];
	GetClientAbsOrigin(Smoker,SmokerPosition);
	GetClientAbsOrigin(Victim,VictimPosition);
	new distance = RoundToNearest(GetVectorDistance(SmokerPosition, VictimPosition));

	if (distance > 1000)
	{
		SlapPlayer(Smoker, 0, false);
	}

	return Plugin_Continue;
}

public IsValidClient(client)
{
	if (client == 0)
		return false;

	if (!IsClientConnected(client))
		return false;

	if (!IsClientInGame(client))
		return false;

	if (!IsPlayerAlive(client))
		return false;

	return true;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
        if (client == 0 || !IsValidEntity(client) || !IsClientInGame(client))
                return Plugin_Continue;

	if (GetClientTeam(client) == TEAM_SURVIVORS && !IsFakeClient(client))
	{
        	if (buttons & IN_ATTACK2)
			SetEntProp(client, Prop_Send, "m_iShovePenalty", 0, 1);
	}

	if (GetClientTeam(client) == TEAM_SURVIVORS && g_bAllBotsSpawned && !LeftSafeRoom && g_bIsFirstMap)
	{
		if (GetEntityMoveType(client) != MOVETYPE_NONE || GetEntityMoveType(client) != MOVETYPE_NOCLIP)
			ToggleFreezePlayer(client, true);

		if (RoundCounter == -1 && GetEntityMoveType(client) == MOVETYPE_NONE)
			ToggleFreezePlayer(client, false);
	}

	if (GetClientTeam(client) == TEAM_INFECTED && !IsFakeClient(client))
	{
		if (!GetEntProp(client, Prop_Send, "m_isGhost") && !GetEntProp(client, Prop_Send,"m_isCulling"))
		{
			if (buttons & IN_ATTACK2 && !g_ButtonDelay[client] && IsPlayerAlive(client))
			{
				g_ButtonDelay[client] = true;

				new class = GetEntProp(client, Prop_Send, "m_zombieClass");

				if (class == 5) // Jockey Class
				{
					new victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
					if (IsValidEntity(victim) && victim != 0)
					{
						SetCommandFlags("dismount", GetCommandFlags("dismount") & ~FCVAR_CHEAT);
						FakeClientCommand(client, "dismount");
						SetCommandFlags("dismount", GetCommandFlags("dismount")|FCVAR_CHEAT);
					}
				}

                                if (class == 3) // Hunter Class
                                {
                                        new victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
                                        if (IsValidEntity(victim) && victim != 0)
                                        {
                                                SDKCall(g_hPounceEnd, client);
                                        }
                                }

                                if (class == 6) // Charger Class
                                {
                                        new victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
                                        if (IsValidEntity(victim) && victim != 0)
                                        {
						SDKCall(g_hOnPummelEnded, client, true, -1);
						new CustomAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
						new Float:ChargeInterval = GetConVarFloat(FindConVar("z_charge_interval"));
						SDKCall(g_hStartActivationTimer, CustomAbility, ChargeInterval, 0.0);
						if (g_bChargerPummel)
							g_bChargerPummel = false;
                                        }
                                }

				CreateTimer(3.0, Timer_DelayButton, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			if (buttons & IN_RELOAD && !g_ButtonDelay[client] && IsPlayerAlive(client))
			{
				g_ButtonDelay[client] = true;

				new class = GetEntProp(client, Prop_Send, "m_zombieClass");

				if (class == 2)
				{
					SetEntityHealth(client, 1);
					IgniteEntity(client, 2.0);
				}

				CreateTimer(3.0, Timer_DelayButton, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}

	if (GetClientTeam(client) == TEAM_SURVIVORS && !IsFakeClient(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge") && GetEntProp(client, Prop_Send, "m_pummelVictim") != 1)
		{
                	if ((buttons & IN_DUCK) && !g_ButtonDelay[client])
			{
				g_ButtonDelay[client] = true;

                	        new rescuer = GetEntProp(client, Prop_Send, "m_reviveOwner");

                	        if (rescuer > 0)
                	                PrintToChat(client, "\x04You cannot let go while being rescued.");
                	        else
				{
                	                if (HangTime[client] < GetGameTime())
					{
				                SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
                				SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0);
				                SetEntProp(client, Prop_Send, "m_isFallingFromLedge", 0);

						if ((Health[client] - 4) > 0)
                        				SetEntityHealth(client, Health[client] - 4);
                				else
                        				SetEntityHealth(client, 1);

				                ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangTwoHands");
						ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangOneHand");
                				ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFingers");
                				ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangAboutToFall");
                				ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFalling");
					}

                	                else
                	                        PrintToChat(client, "\x04You must hang for at least 3s before letting go.");
                	        }

				CreateTimer(3.0, Timer_DelayButton, client, TIMER_FLAG_NO_MAPCHANGE);
                	}
        	}

		else
		{
	        	if (!GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			{
				Health[client] = GetClientHealth(client);
        		        HangTime[client] = GetGameTime() + 3;
			}
		}
	}

	return Plugin_Continue;
}

public Action:Timer_DelayButton(Handle:hTimer, any:Client)
{
        g_ButtonDelay[Client] = false;
}

ToggleFreezePlayer(client, bool:freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

public Sub_FindEntityByClassname(StartEntity, const String:ClassName[])
{
	while (StartEntity > -1 && !IsValidEntity(StartEntity))
	{
		StartEntity--;
	}

	return FindEntityByClassname(StartEntity, ClassName);
}

public Sub_CheckpointDoorControl(Operation)
{
	decl String:sModelName[255];
	decl String:sCurrentMap[64];
        new Entity = -1;

	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	while((Entity = Sub_FindEntityByClassname(Entity, "prop_door_rotating_checkpoint")) != -1)
	{
		GetEntPropString(Entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "01") != -1)
		{
			SetEntProp(Entity, Prop_Data, "m_spawnflags", Operation ? 40960 : 8192);
		}
	}

	LogMessage("[+] S_CDC: Checkpoint Door %s: (Map: %s)", Operation ? "Lock" : "Open", sCurrentMap);
}

stock Sub_SetTimeOut(client)
{
	decl String:ipaddr[24];
	decl String:cmd[100];
	GetClientIP(client, ipaddr, sizeof(ipaddr));

	if (!StrEqual(ipaddr,"loopback",false))
	{
		Format (cmd, sizeof(cmd), "cl_timeout %i", 90);
		ClientCommand(client, cmd);
	}
}

public Action:Cmd_WarpPlayer(client, args)
{
        decl String:sMap[64];
        GetCurrentMap(sMap, sizeof(sMap));

        if (StrContains(sMap, "c2m5_concert", false) == -1)
                return;

        if (!g_bFinaleHasStarted || g_bWarpEnable[client] || client == 0)
                return;

        decl Float:position[3];

        position[0] = -2308.6;
        position[1] = 3358.1;
        position[2] = -114.1;

        if (IsClientInGame(client))
        {
                if (IsPlayerAlive(client) && GetClientTeam(client) != 1)
                {
                        TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
			g_bWarpEnable[client] = true;
			LogMessage("[+] C_WP: Warping Player (%N) to Finale Area.", client);
                }
        }
}

public Action:Event_FinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
        g_bFinaleHasStarted = true;

        decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

        if (StrContains(sMap, "c2m5_concert", false) != -1)
        {
                for (new i = 1; i <= MaxClients; i++)
                {
                        g_bWarpEnable[i] = false;
                }

		PrintHintTextToAll("Type !warp to teleport to stage area\nif you're stuck inside stage hall.");
        }
}

Sub_FilterCvar(String:CvarName[])
{
	new flags, Handle:hFilter = FindConVar(CvarName);
        flags = GetConVarFlags(hFilter);
        flags &= ~FCVAR_NOTIFY;
        SetConVarFlags(hFilter, flags);
        CloseHandle(hFilter);
}
