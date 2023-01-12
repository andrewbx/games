#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

#define PLUGIN_VERSION "1.0"
#define LOCK_DELAY_1 60
#define LOCK_DELAY_2 20

#define ROUND_LAST 0
#define ROUND_THIS 1
#define ROUND_SIZE 2

#define MAX_TEAM_SWITCH 5
#define L4D_MAXPLAYERS 32

// For cvars
new Handle:h_AfkWarnSpecTime;
new Handle:h_AfkSpecTime;
new Handle:h_AfkWarnKickTime;
new Handle:h_AfkKickTime;
new Handle:h_AfkCheckInterval;
new Handle:h_AfkKickEnabled;
new Handle:h_AfkSpecOnConnect;
new afkWarnSpecTime;
new afkSpecTime;
new afkWarnKickTime;
new afkKickTime;
new afkCheckInterval;
new bool:afkKickEnabled;
new bool:afkSpecOnConnect;
new bool:LeavedSafeRoom = false;
new bool:RoundStarted = false;
new bool:g_bIsFirstRound = true;
new String:afkTeamHintText[200];

// work variables
new bool:afkManager_Active;
new afkPlayerTimeLeftWarn[L4D_MAXPLAYERS + 1];
new afkPlayerTimeLeftAction[L4D_MAXPLAYERS + 1];
new afkPlayerTrapped[L4D_MAXPLAYERS + 1];
new Float:afkPlayerLastPos[L4D_MAXPLAYERS + 1][3];
new Float:afkPlayerLastEyes[L4D_MAXPLAYERS + 1][3];
new Handle:afkTimer = INVALID_HANDLE;
new bool:PlayerJustConnected[L4D_MAXPLAYERS + 1];

new PlayerTeams[ROUND_SIZE][L4D_MAXPLAYERS + 1];
new Handle:h_CheckTeamsTimer[L4D_MAXPLAYERS + 1] = {INVALID_HANDLE,...};

new GameMode;
new g_iInfectedLimit;
new g_iSurvivorLimit;
new g_iCount;
new g_iTeamSwitchCount[L4D_MAXPLAYERS+1] = {0,...}
new bool:g_bCommandLock = false;

// Sdk calls
new Handle:gConf = INVALID_HANDLE;
new Handle:fSHS = INVALID_HANDLE;
new Handle:fTOB = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "AFK/Team Manager",
	author = "XBetaAlpha",
	description = "AFK/Team Manager (VS)",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	// We register the spectate command
	RegConsoleCmd("sm_away", Cmd_SwitchToSpectator, "Take a break.");
	RegConsoleCmd("sm_team", Cmd_ChangeTeam, "Display Change Team Menu.");
	RegConsoleCmd("sm_teams", Cmd_ChangeTeam, "Display Change Team Menu.");
	RegConsoleCmd("jointeam", Cmd_JoinTeam, "Join a team.");
	RegConsoleCmd("sm_votekick", Cmd_VoteKick, "Vote Kick User.");

	// For roundstart and roundend..
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_left_start_area", PlayerLeftStart);
	HookEvent("finale_vehicle_leaving", afkEventFinaleLeaving, EventHookMode_Pre);

        gConf = LoadGameConfigFile("l4d2_team");

        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        fSHS = EndPrepSDKCall();

        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
        fTOB = EndPrepSDKCall();

	// Afk manager time limits
	h_AfkWarnSpecTime = CreateConVar("l4d_specafk_warnspectime", "40", "Warn time before spec", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkSpecTime = CreateConVar("l4d_specafk_spectime", "5", "time before spec (after warn)", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkWarnKickTime = CreateConVar("l4d_specafk_warnkicktime", "175", "Warn time before kick (while already on spec)", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkKickTime = CreateConVar("l4d_specafk_kicktime", "5", "time before kick (while already on spec after warn)", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkCheckInterval = CreateConVar("l4d_specafk_checkinterval", "5", "Check/warn interval", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkKickEnabled = CreateConVar("l4d_specafk_kickenabled", "0", "If kick enabled on afk while on spec", FCVAR_PLUGIN, false, 0.0, false, 0.0);
	h_AfkSpecOnConnect = CreateConVar("l4d_specafk_speconconnect", "0", "If player will be forced to spectate on connect", FCVAR_PLUGIN, false, 0.0, false, 0.0);

	// Hook cvars changes ...
	HookConVarChange(h_AfkWarnSpecTime, ConVarChanged);
	HookConVarChange(h_AfkSpecTime, ConVarChanged);
	HookConVarChange(h_AfkWarnKickTime, ConVarChanged);
	HookConVarChange(h_AfkKickTime, ConVarChanged);
	HookConVarChange(h_AfkCheckInterval, ConVarChanged);
	HookConVarChange(h_AfkKickEnabled, ConVarChanged);
	HookConVarChange(h_AfkSpecOnConnect, ConVarChanged);

	// We register the version cvar
	CreateConVar("l4d_specafk_version", PLUGIN_VERSION, "Version of L4D AFK/Team Manager", FCVAR_PLUGIN);

	// We tweak some settings ..
	SetConVarInt(FindConVar("vs_max_team_switches"), 9999); // so that players can switch multiple times

	// We read the cvars
	ReadCvars();
	afkRegisterEvents();

	for (new i = 1; i <= L4D_MAXPLAYERS; i++)
	{
		PlayerTeams[ROUND_LAST][i] = -1;
		PlayerTeams[ROUND_THIS][i] = -1;
	}
}

public ReadCvars()
{
	// first we read all the variables ...
	afkWarnSpecTime = GetConVarInt(h_AfkWarnSpecTime);
	afkSpecTime = GetConVarInt(h_AfkSpecTime);
	afkWarnKickTime = GetConVarInt(h_AfkWarnKickTime);
	afkKickTime = GetConVarInt(h_AfkKickTime);
	afkCheckInterval = GetConVarInt(h_AfkCheckInterval);
	afkKickEnabled = GetConVarBool(h_AfkKickEnabled);
	afkSpecOnConnect = GetConVarBool(h_AfkSpecOnConnect);
}

public ConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ReadCvars();
}

public OnMapStart()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		PlayerJustConnected[i] = false;
		g_iTeamSwitchCount[i] = 0;
	}

	g_iSurvivorLimit = GetConVarInt(FindConVar("survivor_limit"));
	g_iInfectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));

	// We read all the cvars
	ReadCvars();
}

public OnMapEnd()
{
        afkManager_Stop();
	RoundStarted = false;
	g_bIsFirstRound = true;
}

public Action:Timer_CheckTeams(Handle:hTimer, any:client)
{
	if (h_CheckTeamsTimer[client] == INVALID_HANDLE || !RoundStarted)
		return Plugin_Continue;

	new _iInfected = Sub_CountTeam(3, false, false);
	new _iSurvivors = Sub_CountTeam(2, false, false);

	//LogMessage("[+] Check Teams Timer in Progress for all clients (%d/%d).", _iSurvivors, _iInfected);

        if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			//LogMessage("[+] Client is in Game: %N (%d), This: %d, Last: %d", client, client, PlayerTeams[ROUND_THIS][client], PlayerTeams[ROUND_LAST][client]);

			if (PlayerTeams[ROUND_THIS][client] == 3 && PlayerTeams[ROUND_LAST][client] > 1)
			{
				if (_iInfected < g_iInfectedLimit)
				{
					if (GetClientTeam(client) != PlayerTeams[ROUND_THIS][client])
						Sub_SetPlayerInfected(client);
				}
			}

			else if (PlayerTeams[ROUND_THIS][client] == 2 && PlayerTeams[ROUND_LAST][client] > 1)
			{
				if (_iSurvivors < g_iSurvivorLimit)
				{
					if (GetClientTeam(client) != PlayerTeams[ROUND_THIS][client])
						Sub_SetPlayerSurvivor(client);
				}
			}

			else if (PlayerTeams[ROUND_LAST][client] == 1)
				Sub_SetPlayerSpectator(client);

			else if (PlayerTeams[ROUND_THIS][client] == 2 && PlayerTeams[ROUND_LAST][client] == -1)
				Sub_SetPlayerSpectator(client);

			else if (PlayerTeams[ROUND_THIS][client] == 3 && PlayerTeams[ROUND_LAST][client] == -1)
				Sub_SetPlayerSpectator(client);

			h_CheckTeamsTimer[client] = INVALID_HANDLE;
		}
		else
			h_CheckTeamsTimer[client] = INVALID_HANDLE;
	}

	else if (PlayerTeams[ROUND_LAST][client] == -1)
	{
                //LogMessage("[+] Client is not in Game, Setting Invalid: This: %d, Last: %d", PlayerTeams[ROUND_THIS][client], PlayerTeams[ROUND_LAST][client]);
		h_CheckTeamsTimer[client] = INVALID_HANDLE;
	}

	return Plugin_Continue;
}

public Sub_SetPlayerSurvivor(any:client)
{
	if (client == 0 || !IsClientInGame(client))
		return;

	new bot = Sub_FindBot(false);
	if (bot != 0)
	{
		ChangeClientTeam(client, 1);
		SDKCall(fSHS, bot, client);
		SDKCall(fTOB, client, true);
		LogMessage("[AFK/TM] %N (%d) placed onto Survivors team. (BOT Takeover:%N)", client, client, bot);
		PlayerTeams[ROUND_THIS][client] = -1;
		PlayerTeams[ROUND_LAST][client] = -1;
	}
}

public Sub_SetPlayerInfected(any:client)
{
	if (client == 0 || !IsClientInGame(client))
		return;

	ChangeClientTeam(client, 3);
	LogMessage("[AFK/TM] %N (%d) placed onto Infected team.", client, client);
	PlayerTeams[ROUND_THIS][client] = -1;
	PlayerTeams[ROUND_LAST][client] = -1;
}

public Sub_SetPlayerSpectator(any:client)
{
	if (client == 0 || !IsClientInGame(client))
		return;

	if (IsFinalMap())
		ChangeClientTeam(client, 3);
	else
		ChangeClientTeam(client, 0);

	CreateTimer(1.0, afkForceSpectateJoin, client);
	LogMessage("[AFK/TM] %N (%d) placed onto Spectators team.", client, client);
	PlayerTeams[ROUND_THIS][client] = -1;
	PlayerTeams[ROUND_LAST][client] = -1;
}

public OnClientPutInServer(client)
{
	if (LeavedSafeRoom)
		PlayerJustConnected[client] = true;
	else
		PlayerJustConnected[client] = false;

	if (GameMode == 2)
	{
		if (client && !IsFakeClient(client))
		{
			h_CheckTeamsTimer[client] = CreateTimer(0.01, Timer_CheckTeams, client, TIMER_FLAG_NO_MAPCHANGE)
        	        CreateTimer(35.0, JoinAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnClientDisconnect(client)
{
	if (!RoundStarted)
		return;

	PlayerTeams[ROUND_THIS][client] = -1;
	PlayerTeams[ROUND_LAST][client] = -1;
}

public Action:JoinAnnounce(Handle:timer, any:client)
{
        if (IsClientInGame(client))
        {
		PrintToChat(client, "\x01Type \x03!team \x01to to choose team and view connected players.");
		PrintToChat(client, "\x01Type \x03!away \x01to take a break (Autoidle: \x03%d\x01s).", GetConVarInt(h_AfkWarnSpecTime)+GetConVarInt(h_AfkSpecTime));
	}
}

public IsValidClient (client)
{
	if ((client >= 1) && (client <= MaxClients))
		return true;
	else
		return false;
}

public IsValidPlayer (client)
{
	if (client == 0)
		return false;

	if (!IsClientConnected(client))
		return false;

	if (IsFakeClient(client))
		return false;

	if (!IsClientInGame(client))
		return false;

	return true;
}

bool:IsClientMember (client)
{
	if (!IsValidPlayer (client))
		return false;

	new AdminId:id = GetUserAdmin(client);

	if (id == INVALID_ADMIN_ID)
		return false;

	if (GetAdminFlag(id, Admin_Reservation)||GetAdminFlag(id, Admin_Root)||GetAdminFlag(id, Admin_Kick))
		return true;
	else
		return false;
}

public Action:Event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	if (RoundStarted)
		return Plugin_Continue;

	RoundStarted = true;

	if (g_bIsFirstRound)
		g_iCount = LOCK_DELAY_1;
	else
		g_iCount = LOCK_DELAY_2;

	g_bCommandLock = true;
	LogMessage("[+] E_RS: Timer Team Switch Command Lock Started. (Delay: %ds)", g_iCount);
	CreateTimer(1.0, Timer_CommandLock, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

        new String:GameName[16];
        GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
        if (StrContains(GameName, "survival", false) != -1)
                GameMode = 3;
        else if (StrContains(GameName, "versus", false) != -1)
                GameMode = 2;
        else if (StrContains(GameName, "teamversus", false) != -1)
                GameMode = 2;
        else if (StrContains(GameName, "scavenge", false) != -1)
                GameMode = 2;
        else if (StrContains(GameName, "teamscavenge", false) != -1)
                GameMode = 2;
        else if (StrContains(GameName, "mutation12", false) != -1)
                GameMode = 2;
        else if (StrContains(GameName, "coop", false) != -1)
                GameMode = 1;

        g_iSurvivorLimit = GetConVarInt(FindConVar("survivor_limit"));
        g_iInfectedLimit = GetConVarInt(FindConVar("z_max_player_zombies"));

	LeavedSafeRoom = false;

	if (GameMode == 2)
	{
		afkManager_Start();

		if (!g_bIsFirstRound)
		{
	        	for (new i = 1; i <= MaxClients; i++)
	        	{
				if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1)
					Sub_SetPlayerSpectator(i);

				//h_CheckTeamsTimer[i] = CreateTimer(2.0, Timer_CheckTeams, i, TIMER_REPEAT);
			}
		}
	}

	else
		afkManager_Stop();

	return Plugin_Continue;
}


public Action:PlayerLeftStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!LeavedSafeRoom)
	{
       		if (RoundStarted)
       		{
       		        SetConVarInt(FindConVar("sv_alltalk"), 0);
       		        PrintToChatAll("\x05All Talk Disabled, you may no longer speak amongst all teams.");
       		}

		LeavedSafeRoom = true;
	}

	return Plugin_Continue;
}

public Action:afkEventFinaleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (afkManager_Active)
		afkManager_Stop();
}

public Action:Event_RoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!RoundStarted)
		return Plugin_Continue;

	afkManager_Stop();

	SetConVarInt(FindConVar("sv_alltalk"), 1);
	PrintToChatAll("\x05All Talk Enabled, you may speak now amongst all teams until next round start.");

	for (new i = 1; i <= MaxClients; i++)
	{
		PlayerTeams[ROUND_LAST][i] = -1;
		h_CheckTeamsTimer[i] = INVALID_HANDLE;
		afkResetTimers(i);
	}

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i))
		{
			if (!IsFakeClient(i))
                	{
				new Team = GetClientTeam(i);

				switch (Team)
				{
					case 0: PlayerTeams[ROUND_LAST][i] = -1;
					case 1:	PlayerTeams[ROUND_LAST][i] = 1;
					case 2:	PlayerTeams[ROUND_LAST][i] = 2;
					case 3:	PlayerTeams[ROUND_LAST][i] = 3;
				}
			}

			else
				PlayerTeams[ROUND_LAST][i] = -1;
		}
        }

	g_bCommandLock = true;
	g_bIsFirstRound = false;
	RoundStarted = false;

	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
        new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

        if (Client != 0 && IsClientInGame(Client))
        {
                if (!IsFakeClient(Client))
                {
                        new NewTeam = GetEventInt(hEvent, "team");

			switch (NewTeam)
			{
				case 0: PlayerTeams[ROUND_THIS][Client] = -1;
				case 1: PlayerTeams[ROUND_THIS][Client] = 1;
				case 2: PlayerTeams[ROUND_THIS][Client] = 2;
				case 3: PlayerTeams[ROUND_THIS][Client] = 3;
			}
		}

		else
			PlayerTeams[ROUND_THIS][Client] = -1;
	}
}

Sub_DisplayHint(any:client)
{
	if (client != 0 && !IsClientInGame(client))
		return;

	if (GetClientTeam(client) != 1)
		return;

	new _iInfected = Sub_CountTeam(3, false, false);
	new _iSurvivors = Sub_CountTeam(2, false, false);

	if (_iInfected < 4 && _iSurvivors < 4)
		Format(afkTeamHintText, sizeof(afkTeamHintText), "Press M to choose team and join the game. (S:%d/I:%d)", _iSurvivors, _iInfected);

	else if (_iInfected >= g_iInfectedLimit && _iSurvivors >= g_iSurvivorLimit)
		Format(afkTeamHintText, sizeof(afkTeamHintText), "Teams are full, you may only spectate. (S:%d/I:%d)", _iSurvivors, _iInfected);

	else
		Format(afkTeamHintText, sizeof(afkTeamHintText), "Type !team to choose team and join the game. (S:%d/I:%d)", _iSurvivors, _iInfected);

	PrintHintText(client, afkTeamHintText);
}

afkRegisterEvents()
{
	HookEvent("player_team", afkChangedTeam);
	HookEvent("entity_shoved", afkPlayerAction);
	HookEvent("player_shoved", afkPlayerAction);
	HookEvent("player_shoot", afkPlayerAction);
	HookEvent("player_jump", afkPlayerAction);
	HookEvent("player_hurt", afkPlayerAction);
	HookEvent("player_hurt_concise", afkPlayerAction);
	HookEvent("player_incapacitated", afkEventIncap);
	HookEvent("player_ledge_grab", afkEventIncap);
	HookEvent("revive_success", afkEventRevived);

	HookEvent("player_entered_checkpoint", afkEventStartCheck);
	HookEvent("player_left_checkpoint", afkEventStopCheck);

	HookEvent("tongue_grab", afkEventStartGrab);
	HookEvent("choke_start", afkEventStartGrab);
	HookEvent("tongue_release", afkEventStopGrab);
	HookEvent("lunge_pounce", afkEventStartGrab);
	HookEvent("pounce_end", afkEventStopGrab);
	HookEvent("pounce_stopped", afkEventStopGrab);
}

public Action:afkEventStartGrab (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Victim = GetClientOfUserId(GetEventInt(event, "victim"));

	if (Victim > 0)
		afkPlayerTrapped[Victim] = true;
}

public Action:afkEventStopGrab (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Victim = GetClientOfUserId(GetEventInt(event, "victim"));

	if (Victim > 0)
		afkPlayerTrapped[Victim] = false;
}


public Action:afkEventStartCheck (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (Client > 0)
		afkPlayerTrapped[Client] = true;
}

public Action:afkEventStopCheck (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (Client > 0)
		afkPlayerTrapped[Client] = false;
}

public Action:afkEventIncap (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (Client > 0)
		afkPlayerTrapped[Client] = true;
}

public Action:afkEventRevived (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Subject = GetClientOfUserId(GetEventInt(event, "subject"));

	if (Subject > 0)
		afkPlayerTrapped[Subject] = false;
}

public Action:afkPlayerAction (Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:propname[200];

	if (strcmp(name, "entity_shoved", false) == 0)
		propname = "attacker";
	else if (strcmp(name, "player_shoved", false) == 0)
		propname = "attacker";
	else if (strcmp(name, "player_hurt", false) == 0)
		propname = "attacker";
	else if (strcmp(name, "player_hurt_concise", false) == 0)
		propname = "attacker";
	else
		propname = "userid";

	new Client = GetClientOfUserId(GetEventInt(event, propname));

	if (Client > 0)
		afkResetTimers(Client);
}

public Action:afkChangedTeam (Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim > 0)
	{
		if (IsClientConnected(victim) && (!IsFakeClient(victim)))
		{
			if (LeavedSafeRoom && PlayerJustConnected[victim] && afkSpecOnConnect)
			{
				if ((GetClientTeam(victim) == 2) && (!IsPlayerAlive(victim)))
					return Plugin_Continue;

				CreateTimer(0.1, afkForceSpectateJoin, victim);
			}

			PlayerJustConnected[victim] = false;

			afkResetTimers(victim);
			afkPlayerTrapped[victim] = false;
		}
	}

	return Plugin_Continue;
}

public Action:afkJoinHint (Handle:Timer, any:client)
{
	if (!RoundStarted)
		return;

	if ((client > 0) && IsClientInGame(client))
	{
		if (GetClientTeam(client) == 1)
		{
               		PrintHintText(client, afkTeamHintText);
			CreateTimer(5.0, afkJoinHint, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

afkResetTimers (client)
{
	if (!IsValidClient(client))
		return;

	if (!IsClientInGame(client) || IsFakeClient(client))
		return;

	if (GetClientTeam(client) != 1)
	{
		afkPlayerTimeLeftWarn[client] = afkWarnSpecTime;
		afkPlayerTimeLeftAction[client] = afkSpecTime;
	}

	else
	{
		afkPlayerTimeLeftWarn[client] = afkWarnKickTime;
		afkPlayerTimeLeftAction[client] = afkKickTime;
	}

	if (PlayerJustConnected[client])
	{
		afkPlayerTimeLeftWarn[client] = afkPlayerTimeLeftWarn[client] * 2;
	}

	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		GetClientAbsOrigin(client, afkPlayerLastPos[client]);
		GetClientEyeAngles(client, afkPlayerLastEyes[client]);
	}
}

afkManager_Start()
{
	afkManager_Active = true;

	for (new i = 1; i <= MaxClients; i++)
	{
		afkResetTimers(i);
		afkPlayerTrapped[i] = false;
	}

	afkTimer = CreateTimer(float(afkCheckInterval), afkCheckThread, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:afkCheckThread(Handle:timer)
{
	if (!afkManager_Active)
		return Plugin_Stop;

	new Float:pos[3];
	new Float:eyes[3];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) != 1)
			{
				if (IsPlayerAlive(i))
				{
					GetClientAbsOrigin(i, pos);
					GetClientEyeAngles(i, eyes);

					if ((pos[0] == afkPlayerLastPos[i][0])&&(pos[1] == afkPlayerLastPos[i][1])&&(pos[2] == afkPlayerLastPos[i][2])&&(eyes[0] == afkPlayerLastEyes[i][0])&&(eyes[1] == afkPlayerLastEyes[i][1])&&(eyes[2] == afkPlayerLastEyes[i][2]))
					{
						if (!afkPlayerTrapped[i])
						{
							if (afkPlayerTimeLeftWarn[i] > 0)
							{
								afkPlayerTimeLeftWarn[i] = afkPlayerTimeLeftWarn[i] - afkCheckInterval;

								if (afkPlayerTimeLeftWarn[i] <= 0)
								{
									afkPlayerTimeLeftAction[i] = afkSpecTime;
									PrintToChat(i, "\x01You will be forced to spectate in \x03%i\x01s.", afkPlayerTimeLeftAction[i]);
								}
							}

							else
							{
								afkPlayerTimeLeftAction[i] = afkPlayerTimeLeftAction[i] - afkCheckInterval;

								if (afkPlayerTimeLeftAction[i] <= 0)
								{
									if (LeavedSafeRoom)
									{
										afkForceSpectate(i,true);
										afkResetTimers(i);
									}

									else
						                		PrintHintText(i, "You'll be forced to spectate when a player has left the safe zone.");
								}

								else
									PrintToChat(i, "\x01You will be forced to spectate in \x03%i\x01s.", afkPlayerTimeLeftAction[i]);
							}
						}

						else
							afkResetTimers(i);
					}

					else
					{
						afkPlayerTrapped[i] = false;
						afkResetTimers(i);
					}
				}
			}

			else if (afkKickEnabled)
			{
				if (!IsClientMember(i))
				{
					if (afkPlayerTimeLeftWarn[i] > 0)
					{
						afkPlayerTimeLeftWarn[i] = afkPlayerTimeLeftWarn[i] - afkCheckInterval;

						if (afkPlayerTimeLeftWarn[i] <= 0)
							PrintToChat(i, "\x01You will be \x03kicked\x01 in \x03%i\x01s.", afkPlayerTimeLeftAction[i]);
					}

					else
					{
						afkPlayerTimeLeftAction[i] = afkPlayerTimeLeftAction[i] - afkCheckInterval;

						if (afkPlayerTimeLeftAction[i] <=  0)
						{
							if (LeavedSafeRoom)
								afkKickClient(i);
							else
                                                                PrintHintText(i, "You'll be kicked when a player has left the safe zone.");
						}

						else
							PrintToChat(i, "\x01You will be \x03kicked\x01 in \x03%i\x01s.", afkPlayerTimeLeftAction[i]);
					}
				}
			}

			else
				Sub_DisplayHint(i);
		}
	}

	return Plugin_Continue;
}

afkForceSpectate (client, bool:advertise)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;

	new offsetIsGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");

	if (GetClientTeam(client) == 3)
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		{
			if (GetEntData(client, offsetIsGhost, 1) != 1)
				ForcePlayerSuicide(client);
		}
	}

	ChangeClientTeam(client, 1);

	if (advertise)
		PrintToChatAll("\x01%N is now idle.", client);
}

public Action:afkForceSpectateJoin (Handle:timer, any:client)
{
	afkForceSpectate(client, false);
}

afkKickClient (client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;

	new offsetIsGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");

	if (GetClientTeam(client) == 3)
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		{
			if (GetEntData(client, offsetIsGhost, 1) != 1)
				ForcePlayerSuicide(client);
		}
	}

	KickClient(client, "Idle status exceeded limit (%ds)", afkWarnKickTime+afkKickTime);
	PrintToChatAll("Player %N was kicked for exceeding idle limit (%ds).", client, afkWarnKickTime+afkKickTime);
}

afkManager_Stop()
{
	if (!afkManager_Active)
		return;

	afkManager_Active = false;

	if (afkTimer != INVALID_HANDLE)
	{
		KillTimer(afkTimer, false);
		afkTimer = INVALID_HANDLE;
	}
}

public Action:Cmd_JoinTeam(client, args)
{
	if (args < 1)
	{
		PrintToChat(client, "Invalid team specified. Command Usage: jointeam (1=Survivors, 2=Infected, 3=Specators)");
		return Plugin_Handled;
	}

	decl String:_Arg[255];
	new _TeamNo;

        GetCmdArg(1, _Arg, sizeof(_Arg));

	if (StrContains(_Arg, "Infected", false) != -1)
		_TeamNo = 3;

	else if (StrContains(_Arg, "Survivor", false) != -1)
		_TeamNo = 2;

	else
		_TeamNo = StringToInt(_Arg);

	switch (_TeamNo)
	{
		case 1: { Cmd_SwitchToSpectator(client,args); }
		case 2: { Cmd_SwitchToSurvivors(client,args); }
		case 3: { Cmd_SwitchToInfected(client,args); }
	}

	return Plugin_Handled;
}

public Action:Cmd_ChangeTeam(client, args)
{
	decl String:_sBuffer [20];
	decl String:_iBuffer [20];
	decl String:_spBuffer [20];
	decl String:_mBuffer [30];

	new _sCount = Sub_CountTeam(2,false,false);
	new _iCount = Sub_CountTeam(3,false,false);
	new _sFCount = Sub_CountTeam(2,true,false);
	new _iFCount = Sub_CountTeam(3,true,false);
	new _spCount = Sub_CountTeam(1,false,false);
	new _spFCount = Sub_CountTeam(1,true,false);

	Format(_sBuffer, sizeof(_sBuffer), "Survivors (%i/%i/%i)", _sCount, _sFCount, g_iSurvivorLimit);
	Format(_iBuffer, sizeof(_iBuffer), "Infected (%i/%i/%i)", _iCount, _iFCount, g_iInfectedLimit);
	Format(_spBuffer, sizeof(_spBuffer), "Spectators (%i/%i/%i)", _spCount, _spFCount, (g_iInfectedLimit+g_iSurvivorLimit));
	Format(_mBuffer, sizeof(_mBuffer), "(L4D+) Team Menu\r \r");

	new Handle:hMenu = CreateMenu(MenuExecute);
	SetMenuTitle(hMenu, _mBuffer);
	AddMenuItem(hMenu, "", _sBuffer);
	AddMenuItem(hMenu, "", _iBuffer);
	AddMenuItem(hMenu, "", _spBuffer);
	AddMenuItem(hMenu, "", "View Players");
	AddMenuItem(hMenu, "", "Vote Kick");

	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, 20);

	return Plugin_Handled;
}

public MenuExecute(Handle:hCurrentMenu, MenuAction:State, Param1, Param2)
{
	switch (State)
	{
		case MenuAction_Select:
		{
			switch(Param2)
			{
				case 0: { Cmd_SwitchToSurvivors(Param1,Param2); }
                		case 1: { Cmd_SwitchToInfected(Param1,Param2); }
				case 2: { Cmd_SwitchToSpectator(Param1,Param2); }
				case 3: { ShowPlayerHud(Param1); }
				case 4: { Cmd_VoteKick(Param1, Param2); }
			}
		}
		case MenuAction_End:
		{
			CloseHandle(hCurrentMenu);
		}
	}
}

public Action:Cmd_VoteKick(client, args)
{
	new Handle:hMenu = CreateMenu(MenuVoteKick);
	new ClientTeam = GetClientTeam(client);

	decl String:_sBuffer [32];
	decl String:_sUID [12];

	SetMenuTitle(hMenu, "Vote Kick Menu\r \r");

	if (client == 0)
		return Plugin_Handled;

	for (new i = 1; i <= MaxClients; i++)
	{
                if (IsClientInGame(i) && !IsFakeClient(i) && i != client)
		{
                        if (GetClientTeam(i) == ClientTeam || GetClientTeam(i) == 1)
			{
                                Format(_sUID, sizeof(_sUID), "%i", GetClientUserId(i));
                                Format(_sBuffer, sizeof(_sBuffer), "%N", i);
                                AddMenuItem(hMenu, _sUID, _sBuffer);
			}
		}
	}

	DisplayMenu(hMenu, client, 20);

	return Plugin_Handled;
}

public MenuVoteKick(Handle:hVoteKickMenu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			decl String:_sUserID[12];
			GetMenuItem(hVoteKickMenu, param2, _sUserID, sizeof(_sUserID));

			new client = GetClientOfUserId(StringToInt(_sUserID));

			if (client == 0 || !IsClientConnected(client))
				PrintToChat(param1, "Player %N is no longer available.", client);
			else
				FakeClientCommand(param1, "callvote kick %d", client);
		}

		case MenuAction_End:
		{
			CloseHandle(hVoteKickMenu);
		}
	}
}

public Action:Cmd_SwitchToInfected(client, args)
{
        if (IsClientInGame(client) && !IsFakeClient(client))
	{
		if (g_iTeamSwitchCount[client] >= MAX_TEAM_SWITCH)
		{
			PrintToChat(client, "\x01You can no longer switch teams for this map. (Limit:\x03%d\x01)", MAX_TEAM_SWITCH);
			return Plugin_Handled;
		}

		if (g_bCommandLock)
		{
			PrintToChat(client, "\x01You cannot switch to infected right now (Delay:\x03%d\x01s)", g_iCount);
			return Plugin_Handled;
		}

                if (GetClientTeam(client) == 3)
                        PrintToChat(client, "\x01You are already on the infected team.");

                else if (Sub_CountTeam(3,false,false) >= g_iInfectedLimit)
                                PrintToChat(client, "\x01Team is full (Max: \x03%d\x01 Infected).", g_iInfectedLimit);
                else
		{
                        ChangeClientTeam(client, 3);
			PrintToChatAll("\x01Player \x03%N \x01has switched to \x03Infected\x01. (%d/%d switches remaining)", client, (MAX_TEAM_SWITCH-1)-g_iTeamSwitchCount[client], MAX_TEAM_SWITCH);
			g_iTeamSwitchCount[client]++;
			return Plugin_Handled;
		}
	}

        return Plugin_Continue;
}

public Action:Cmd_SwitchToSurvivors(client, args)
{
        if (IsClientInGame(client) && !IsFakeClient(client))
	{
		if (g_iTeamSwitchCount[client] >= MAX_TEAM_SWITCH)
		{
			PrintToChat(client, "\x01You can no longer switch teams for this map. (Limit:\x03%d\x01)", MAX_TEAM_SWITCH);
			return Plugin_Handled;
		}

                if (g_bCommandLock)
                {
                        PrintToChat(client, "\x01You cannot switch to survivors right now. (Delay:\x03%d\x01s)", g_iCount);
                        return Plugin_Handled;
                }

                if (GetClientTeam(client) == 2)
                        PrintToChat(client, "\x01You are already on the survivor team.");

                else if (Sub_CountTeam(2,false,false) >= g_iSurvivorLimit)
                                PrintToChat(client, "\x01Team is full (Max: \x03%d\x01 Survivors).", g_iSurvivorLimit);
                else
		{
			new bot = Sub_FindBot(true);
			if (bot != 0)
			{
				ChangeClientTeam(client, 1);
				SDKCall(fSHS, bot, client);
				CreateTimer(0.01, Timer_TakeOverBot, client, TIMER_FLAG_NO_MAPCHANGE);
				LogMessage("[+] C_STS: Player %N, Switched to Survivor:%N.", client, bot);
			}

			else
			{
				PrintToChat(client, "\x01No survivors available. Survivor is dead.");
				return Plugin_Handled;
			}

			PrintToChatAll("\x01Player \x03%N \x01has switched to \x03Survivors\x01. (%d/%d switches remaining)", client, (MAX_TEAM_SWITCH-1)-g_iTeamSwitchCount[client], MAX_TEAM_SWITCH);
			g_iTeamSwitchCount[client]++;
			return Plugin_Handled;
		}
	}

        return Plugin_Continue;
}

public Action:Cmd_SwitchToSpectator(client, args)
{
        if (IsClientInGame(client) && !IsFakeClient(client))
	{
                if (GetClientTeam(client) == 1)
                        PrintToChat(client, "\x01You are already spectating.");
                else
                {
                        ChangeClientTeam(client, 1);
			PrintToChatAll("\x01%N is now idle.", client);
			afkResetTimers(client);
			return Plugin_Handled;
                }
	}

        return Plugin_Continue;
}

Sub_CountTeam(any:_iTeam, bool:_bFake, bool:_bAll)
{
        new _iCount = 0;

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i))
                {
                        if (!_bFake && !_bAll)
                        {
                                if (!IsFakeClient(i) && GetClientTeam(i) == _iTeam)
                                        _iCount++;
                        }
                        else if (_bFake && !_bAll)
                        {
                                if (IsFakeClient(i) && GetClientTeam(i) == _iTeam)
                                        _iCount++;
                        }
			else if (!_bFake && _bAll)
			{
                                if (GetClientTeam(i) == _iTeam)
                                        _iCount++;
			}
                }
        }

        return _iCount;
}

public Action:ShowPlayerHud(any:client)
{
        new Handle:panel = CreatePanel();
        decl String:panelLine[1024];

	Format(panelLine, sizeof(panelLine), "(L4D+) Team Players (%dv%d VS+)", g_iSurvivorLimit, g_iInfectedLimit);

	DrawPanelText(panel, panelLine);
        DrawPanelText(panel, " ");

        Format(panelLine, sizeof(panelLine), "Survivors (%d/%d/%d)", Sub_CountTeam(2,false,false), Sub_CountTeam(2,true,false), g_iSurvivorLimit);
        DrawPanelText(panel, panelLine);
        DrawPanelText(panel, " ");

        new x = 1;
        for (new i = 1; i <= MaxClients; i++)
        {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
                	Format(panelLine, sizeof(panelLine), "->%d. %N", x, i);
                	DrawPanelText(panel, panelLine);
			x++;
		}
        }

        DrawPanelText(panel, " ");
        Format(panelLine, sizeof(panelLine), "Infected (%d/%d/%d)", Sub_CountTeam(3,false,false), Sub_CountTeam(3,true,false), g_iInfectedLimit);
        DrawPanelText(panel, panelLine);
        DrawPanelText(panel, " ");

	x = 1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3)
		{
			Format(panelLine, sizeof(panelLine), "->%d. %N", x, i);
                       	DrawPanelText(panel, panelLine);
			x++;
		}
        }

	x = 0;
        for (new i = 1; i <= MaxClients; i++)
        {
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			switch (GetClientTeam(i))
			{
				case 1: x++;
				case 2: x++;
				case 3: x++;
			}
		}
        }

        DrawPanelText(panel, " ");
	Format(panelLine, sizeof(panelLine), "Connected: %d/%d", x, GetConVarInt(FindConVar("sv_maxplayers")));
        DrawPanelText(panel, panelLine);

	SendPanelToClient(panel, client, Menu_PlayerPanel, 25);
        CloseHandle(panel);

        return Plugin_Continue;
}

public Menu_PlayerPanel(Handle:menu, MenuAction:action, param1, param2) { return; }

public Action:Timer_TakeOverBot(Handle:hTimer, any:Client)
{
	if (IsClientInGame(Client) && !IsFakeClient(Client))
		SDKCall(fTOB, Client, true);
}

public Action:Timer_KickFakeClient(Handle:_hTimer, any:_iClient)
{
        if (IsClientConnected(_iClient) && !IsClientInKickQueue(_iClient) && IsFakeClient(_iClient))
        {
		LogMessage("[AFK/TM] Kicking Fake Client: %N", _iClient);
                KickClient(_iClient,"Kicking Fake Client.");
        }
}

Sub_FindBot(any:DeadCheck)
{
        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2)
                {
			if (DeadCheck)
			{
				if (IsPlayerAlive(i))
		                        return i;
			}

			else
				return i;
                }
        }

	return 0;
}

public Action:Timer_CommandLock(Handle:hTimer)
{
	g_iCount--;

	if (g_iCount == 0)
	{
		g_bCommandLock = false;
		LogMessage("[+] E_RS: Timer Team Switch Command Lock Ended.");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

bool:IsFinalMap()
{
        new String:map[128];
        GetCurrentMap(map, sizeof(map));

        if
	(
                StrContains(map, "l4d_smalltown05_houseboat") != -1 ||
                StrContains(map, "l4d_hospital05_rooftop") != -1 ||
                StrContains(map, "l4d_airport05_runway") != -1 ||
                StrContains(map, "l4d_farm05_cornfield") != -1 ||
                StrContains(map, "l4d_garage02_lots") != -1 ||
                StrContains(map, "l4d_vs_smalltown05_houseboat") != -1 ||
                StrContains(map, "l4d_vs_hospital05_rooftop") != -1 ||
                StrContains(map, "l4d_vs_airport05_runway") != -1 ||
                StrContains(map, "l4d_vs_farm05_cornfield") != -1
	)
		return true;

        if
	(
                StrContains(map, "c1m4_atrium") != -1  ||
                StrContains(map, "c2m5_concert") != -1 ||
                StrContains(map, "c3m4_plantation") != -1 ||
                StrContains(map, "c4m5_milltown_escape") != -1 ||
                StrContains(map, "c5m5_bridge") != -1 ||
		StrContains(map, "c6m3_port") != -1 ||
		StrContains(map, "c7m3_port") != -1 ||
                StrContains(map, "c7m8_rooftop") != -1 ||
		StrContains(map, "l4d2_city17_05") != -1 ||
		StrContains(map, "l4d_deathaboard05_light") != -1
	)
		return true;

        return false;
}
