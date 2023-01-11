// Zombie Character Select 0.8.1 by XBetaAlpha
// Original Concept by Crimson_Fox
// Modified & Tested for Use on [TS] 9v9 VS+ [UK]
// Compiled on SourceMod 1.4.0-dev

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.8.1"
#define FCVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD
#define _DEBUG 0

#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_TANK 7
#define ZC_INDEXSIZE 6

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define PLATFORM_WINDOWS 1
#define PLATFORM_LINUX 2

#define PLAYER_NOTIFY_DELAY 3.5
#define PLAYER_MELEE_INGAME "\x04Press the MELEE key as ghost to change zombie class."
#define TEAM_CLASS(%1)      (%1 == 1 ? "Smoker" : (%1 == 2 ? "Boomer" : (%1 == 3 ? "Hunter" :(%1 == 4 ? "Spitter" : (%1 == 5 ? "Jockey" : (%1 == 6 ? "Charger" : (%1 == 7 ? "Tank" : "Unknown")))))))

new Handle:g_hSetClass = INVALID_HANDLE;
new Handle:g_hCreateAbility = INVALID_HANDLE;
new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:g_hRespectLimits = INVALID_HANDLE;
new Handle:g_hShowHudPanel = INVALID_HANDLE;
new Handle:g_hCountFakeBots = INVALID_HANDLE;
new Handle:g_hSwitchInFinale = INVALID_HANDLE;
new Handle:g_hZCSelectDelay = INVALID_HANDLE;

new bool:g_bIsHoldingMelee[MAXPLAYERS+1]
new bool:g_bIsChanging[MAXPLAYERS+1]
new bool:g_bRoundEnd;
new bool:g_bSwitchDisabled;

new g_iLastClass[MAXPLAYERS+1] = {1,...};
new g_iNextClass[MAXPLAYERS+1] = {1,...};
new g_iZLimits[ZC_INDEXSIZE+1] = {0,...};
new g_oAbility;

public Plugin:myinfo =
{
	name = "Zombie Character Select",
	author = "XBetaAlpha -Original Crimson_Fox",
	description = "Allows infected players to change zombie class in ghost mode.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1016671"
}

public OnPluginStart()
{
	// Left 4 Dead 2 Plugin Only.
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}

	CreateConVar("zcs_version", PLUGIN_VERSION, "Zombie Character Select version.", FCVAR_FLAGS)

	g_hRespectLimits = CreateConVar("zcs_respectlimits", "1", "Respect Director Limits.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hShowHudPanel = CreateConVar("zcs_showhudpanel", "0", "Display Infected Limits Panel.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCountFakeBots = CreateConVar("zcs_countfakebots", "0", "Count Fake Bots in Limits.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
        g_hSwitchInFinale = CreateConVar("zcs_switchinfinale", "1", "Allow Class Switch in Finale.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hZCSelectDelay = CreateConVar("zcs_zcselectdelay", "0.5", "Zombie Class Switch Delay (s).", FCVAR_PLUGIN, true, 0.1, true, 10.0);

        g_hGameConf = LoadGameConfigFile("l4d2_zcs");

        if (g_hGameConf != INVALID_HANDLE)
        {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetClass = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hCreateAbility = EndPrepSDKCall();

                new Platform = GameConfGetOffset(g_hGameConf, "Platform");

                if (Platform == PLATFORM_WINDOWS)
                        g_oAbility = 0x390;
                else
                        g_oAbility = 0x3a4;
        }

        HookEvent("round_start", Event_RoundStart);
        HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_start", Event_FinaleStart);
        HookEvent("player_team", Event_PlayerTeam);
	HookEvent("ghost_spawn_time", Event_GhostSpawnTime);
}

public OnConfigsExecuted()
{
        if (GetConVarInt(g_hRespectLimits) == 1)
        {
                g_iZLimits[ZC_SMOKER] = GetConVarInt(FindConVar("z_versus_smoker_limit"));
                g_iZLimits[ZC_BOOMER] = GetConVarInt(FindConVar("z_versus_boomer_limit"));
                g_iZLimits[ZC_HUNTER] = GetConVarInt(FindConVar("z_versus_hunter_limit"));
                g_iZLimits[ZC_SPITTER] = GetConVarInt(FindConVar("z_versus_spitter_limit"));
                g_iZLimits[ZC_JOCKEY] = GetConVarInt(FindConVar("z_versus_jockey_limit"));
                g_iZLimits[ZC_CHARGER] = GetConVarInt(FindConVar("z_versus_charger_limit"));
        }
}

public Action:Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = false;
	g_bSwitchDisabled = false;
}

public Action:Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = true;
}

public Action:Event_FinaleStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(g_hSwitchInFinale) == 0)
		g_bSwitchDisabled = true;
	else
		g_bSwitchDisabled = false;
}

public Action:Event_PlayerTeam(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

        if (client == 0)
		return;

	CreateTimer(PLAYER_NOTIFY_DELAY, Timer_NotifyKey, client, TIMER_FLAG_NO_MAPCHANGE);
	g_iNextClass[client] = ZC_SMOKER;
	Hud_ShowLimits(client);
}

public Action:Event_GhostSpawnTime(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	CreateTimer(float(GetEventInt(hEvent, "spawntime")) + 0.1, Timer_SpawnGhostClass, client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (client == 0 || !IsValidEntity(client) || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	if (GetEntProp(client, Prop_Send, "m_isGhost") && !g_bRoundEnd && !g_bSwitchDisabled)
	{
		if (buttons & IN_ATTACK2)
		{
			if ((g_bIsHoldingMelee[client] == false) && (g_bIsChanging[client] == false))
			{
				g_bIsHoldingMelee[client] = true;
				g_bIsChanging[client] = true;

				new ZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
				Sub_DetermineClass(client, ZClass);

				CreateTimer(GetConVarFloat(g_hZCSelectDelay), Timer_DelayChange, client, TIMER_FLAG_NO_MAPCHANGE);
				Hud_ShowLimits(client);
			}
		}

		else g_bIsHoldingMelee[client] = false
	}

	if (buttons & IN_ATTACK && GetEntProp(client, Prop_Send, "m_isGhost"))
	{
		CreateTimer(0.1, Timer_SelectDelay, client);
	}

	return Plugin_Continue
}

public Action:Timer_SelectDelay(Handle:hTimer, any:client)
{
	if (!IsValidEntity(client) || !IsClientInGame(client))
		return Plugin_Continue;

	if (!GetEntProp(client, Prop_Send, "m_isGhost"))
	{
		g_iLastClass[client] = GetEntProp(client, Prop_Send, "m_zombieClass")
	}

	return Plugin_Continue;
}

public Action:Timer_NotifyKey(Handle:hTimer, any:client)
{
        if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
        {
                PrintToChat(client, PLAYER_MELEE_INGAME);
        }
}

public Action:Timer_DelayChange(Handle:hTimer, any:client)
{
	g_bIsChanging[client] = false;
}

public Action:Timer_SpawnGhostClass(Handle:hTimer, any:client)
{
	if (client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (!IsValidEntity(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_INFECTED)
		return Plugin_Continue;

	if (!GetEntProp(client, Prop_Send, "m_isGhost"))
		return Plugin_Continue;

	new ZClass = GetEntProp(client, Prop_Send, "m_zombieClass");

	if (ZClass == ZC_TANK)
		return Plugin_Continue;

	if (ZClass == g_iLastClass[client])
	{
		Sub_DetermineClass(client, ZClass);
#if _DEBUG
		LogMessage("[+] (%N) Zombie Class (Director: %s, Last: %s, Replaced: %s)", client, TEAM_CLASS(ZClass), TEAM_CLASS(g_iLastClass[client]), TEAM_CLASS(g_iNextClass[client]));
#endif
	}

	Hud_ShowLimits(client);
	return Plugin_Continue;
}

public Sub_CountInfected(any:ZClass, bool:GetCount)
{
	new ClassCount, ClassType;
	new CountFakeBots = GetConVarInt(g_hCountFakeBots);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 3)
		{
			if (IsValidEntity(i))
			{
				ClassType = GetEntProp(i, Prop_Send, "m_zombieClass");

				if (GetClientHealth(i) > 0)
				{
					if (ClassType == ZClass)
					{
						if (CountFakeBots == 0)
						{
							if (!IsFakeClient(i))
								ClassCount++;
						}
						else
							ClassCount++;
					}
				}
			}
		}
	}

	if (GetCount)
		return ClassCount;

	if (ClassCount < g_iZLimits[ZClass])
		return true;

	return false;
}

public Sub_DetermineClass(any:client, any:ZClass)
{
	switch (ZClass)
	{
		case ZC_SMOKER: g_iNextClass[client] = ZC_BOOMER;
		case ZC_BOOMER: g_iNextClass[client] = ZC_HUNTER;
		case ZC_HUNTER: g_iNextClass[client] = ZC_SPITTER;
		case ZC_SPITTER: g_iNextClass[client] = ZC_JOCKEY;
		case ZC_JOCKEY: g_iNextClass[client] = ZC_CHARGER;
		case ZC_CHARGER: g_iNextClass[client] = ZC_SMOKER;
	}

	if (GetConVarInt(g_hRespectLimits) == 1)
	{
		for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
		{
			if (!Sub_CountInfected(g_iNextClass[client], false) && g_iNextClass[client] == i)
			{
				if (i != ZC_CHARGER)
					g_iNextClass[client] = i + 1;
				else
					g_iNextClass[client] = ZC_SMOKER;
			}
		}
	}

	RemovePlayerItem(client, GetPlayerWeaponSlot(client, 0));
	SDKCall(g_hSetClass, client, g_iNextClass[client]);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, client), g_oAbility));
}

public Hud_ShowLimits(any:client)
{
	if (GetConVarInt(g_hShowHudPanel) != 1)
		return;

	if (!IsClientConnected(client) || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED)
		return;

        new Handle:panel = CreatePanel();
        decl String:panelLine[1024];

        Format(panelLine, sizeof(panelLine), "(L4D+) Infected Limits");
        DrawPanelText(panel, panelLine);
        DrawPanelText(panel, " ");

        for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
        {
		Format(panelLine, sizeof(panelLine), "->%d. (%d/%d) %s", i, Sub_CountInfected(i, true), g_iZLimits[i], TEAM_CLASS(i));
		DrawPanelText(panel, panelLine);
        }

        SendPanelToClient(panel, client, Hud_LimitsPanel, 25);
        CloseHandle(panel);
}

public Hud_LimitsPanel(Handle:hMenu, MenuAction:action, param1, param2)
{
	return;
}
