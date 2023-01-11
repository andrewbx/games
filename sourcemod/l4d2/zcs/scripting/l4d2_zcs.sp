// Zombie Character Select 0.8.3b by XBetaAlpha
//
// Modified & Tested for Use on [TS] 10v10 VS+ [UK]
// Original Concept by Crimson_Fox
// Compiled on SourceMod 1.4.0-dev

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION		"0.8.3b"
#define _DEBUG			0

#define ZC_SMOKER		1
#define ZC_BOOMER		2
#define ZC_HUNTER		3
#define ZC_SPITTER		4
#define ZC_JOCKEY		5
#define ZC_CHARGER		6
#define ZC_TANK			7
#define ZC_TOTAL                7
#define ZC_INDEXSIZE		ZC_TOTAL + 1
#define ZC_TIMEOFFSET		0.1

#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

#define PLATFORM_WINDOWS	1
#define PLATFORM_LINUX		2

#define PLAYER_NOTIFY_DELAY	3.5
#define PLAYER_MELEE_INGAME	"\x04Press the %s key as ghost to change zombie class."
#define PLAYER_LIMITS_UP	"\x04Limits reached. Choose current class or wait. (%d/%d)"
#define PLAYER_CLASSES_UP	"\x04No more classes available. Last class allowed."

#define TEAM_CLASS(%1)     	(%1 == 1 ? "Smoker" : (%1 == 2 ? "Boomer" : (%1 == 3 ? "Hunter" :(%1 == 4 ? "Spitter" : (%1 == 5 ? "Jockey" : (%1 == 6 ? "Charger" : (%1 == 7 ? "Tank" : "Unknown")))))))
#define SELECT_KEY(%1)		(%1 == 1 ? IN_ATTACK2 : (%1 == 2 ? IN_RELOAD : (%1 == 3 ? IN_USE : 0)))
#define PLAYER_KEYS(%1)		(%1 == 1 ? "MELEE" : (%1 == 2 ? "RELOAD" : (%1 == 3 ? "USE" : "Unknown")))

new Handle:g_hSetClass		= INVALID_HANDLE;
new Handle:g_hCreateAbility	= INVALID_HANDLE;
new Handle:g_hGameConf 		= INVALID_HANDLE;

new Handle:g_hRespectLimits 	= INVALID_HANDLE;
new Handle:g_hShowHudPanel 	= INVALID_HANDLE;
new Handle:g_hCountFakeBots 	= INVALID_HANDLE;
new Handle:g_hSwitchInFinale 	= INVALID_HANDLE;
new Handle:g_hAllowLastClass	= INVALID_HANDLE;
new Handle:g_hZCSelectKey	= INVALID_HANDLE;
new Handle:g_hZCSelectDelay 	= INVALID_HANDLE;

new g_bRespectLimits;
new g_bShowHudPanel;
new g_bCountFakeBots;
new g_bSwitchInFinale;
new g_bAllowLastClass;
new g_iZCSelectKey;
new Float:g_fZCSelectDelay;

new g_iLastClass[MAXPLAYERS+1]	= {0,...};
new g_iNextClass[MAXPLAYERS+1]	= {0,...};
new g_iSLastClass[MAXPLAYERS+1] = {0,...};
new g_iZVLimits[ZC_INDEXSIZE]	= {0,...};
new g_iZLimits[ZC_INDEXSIZE]	= {0,...};
new g_oAbility;

new bool:g_bIsHoldingMelee[MAXPLAYERS+1]
new bool:g_bIsChanging[MAXPLAYERS+1]
new bool:g_bRoundEnd = false;
new bool:g_bSwitchDisabled = false;

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

	CreateConVar("zcs_version", PLUGIN_VERSION, "Zombie Character Select version.", FCVAR_PLUGIN|FCVAR_NOTIFY)

	g_hRespectLimits = CreateConVar("zcs_respectlimits", "1", "Respect Director Limits.", FCVAR_PLUGIN);
	g_hShowHudPanel = CreateConVar("zcs_showhudpanel", "0", "Display Infected Limits Panel.", FCVAR_PLUGIN);
	g_hCountFakeBots = CreateConVar("zcs_countfakebots", "0", "Count Fake Bots in Limits.", FCVAR_PLUGIN);
	g_hSwitchInFinale = CreateConVar("zcs_switchinfinale", "1", "Allow Class Switch in Finale.", FCVAR_PLUGIN);
	g_hAllowLastClass = CreateConVar("zcs_allowlastclass", "0", "Allow Player to Select Previous Class.", FCVAR_PLUGIN);
	g_hZCSelectKey = CreateConVar("zcs_zcselectkey", "1", "Key binding for Zombie Selection.", FCVAR_PLUGIN, true, 1.0, true, 3.0);
	g_hZCSelectDelay = CreateConVar("zcs_zcselectdelay", "0.5", "Zombie Class Switch Delay (s).", FCVAR_PLUGIN, true, 0.1, true, 10.0);

	HookConVarChange(g_hRespectLimits, ConVarsChanged);
	HookConVarChange(g_hShowHudPanel, ConVarsChanged);
	HookConVarChange(g_hCountFakeBots, ConVarsChanged);
	HookConVarChange(g_hSwitchInFinale, ConVarsChanged);
	HookConVarChange(g_hAllowLastClass, ConVarsChanged);
	HookConVarChange(g_hZCSelectKey, ConVarsChanged);
	HookConVarChange(g_hZCSelectDelay, ConVarsChanged);

	AutoExecConfig(true, "l4d2_zcs");

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
        Sub_ReloadConVars();
	Sub_ReloadLimits();
}

public Action:Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = false;
	g_bSwitchDisabled = false;

	Sub_ResetArrayClass();
}

public Action:Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = true;
}

public Action:Event_FinaleStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bSwitchInFinale)
		g_bSwitchDisabled = true;
	else
		g_bSwitchDisabled = false;
}

public Action:Event_PlayerTeam(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new NewTeam = GetEventInt(hEvent, "team");

	if (Client == 0 || NewTeam != TEAM_INFECTED)
		return Plugin_Continue;

	CreateTimer(PLAYER_NOTIFY_DELAY, Timer_NotifyKey, Client, TIMER_FLAG_NO_MAPCHANGE);
	Hud_ShowLimits(Client);

	return Plugin_Continue;
}

public Action:Event_GhostSpawnTime(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client) || g_bRoundEnd)
		return Plugin_Continue;

	CreateTimer(float(GetEventInt(hEvent, "spawntime")) + ZC_TIMEOFFSET, Timer_SpawnGhostClass, Client);

	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (Client == 0 || !IsValidEntity(Client) || !IsClientInGame(Client))
	{
		return Plugin_Continue;
	}

	if (GetEntProp(Client, Prop_Send, "m_isGhost") && !g_bRoundEnd && !g_bSwitchDisabled)
	{
		if (buttons & SELECT_KEY(g_iZCSelectKey))
		{
			if ((g_bIsHoldingMelee[Client] == false) && (g_bIsChanging[Client] == false))
			{
				g_bIsHoldingMelee[Client] = true;
				g_bIsChanging[Client] = true;

				new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
				Sub_DetermineClass(Client, ZClass);

				CreateTimer(g_fZCSelectDelay, Timer_DelayChange, Client, TIMER_FLAG_NO_MAPCHANGE);
				Hud_ShowLimits(Client);
			}
		}

		else g_bIsHoldingMelee[Client] = false
	}

	if (buttons & IN_ATTACK && GetEntProp(Client, Prop_Send, "m_isGhost"))
	{
		CreateTimer(0.1, Timer_SelectDelay, Client);
	}

	return Plugin_Continue
}

public Action:Timer_SelectDelay(Handle:hTimer, any:Client)
{
	if (!IsValidEntity(Client) || !IsClientInGame(Client))
		return Plugin_Continue;

	if (!GetEntProp(Client, Prop_Send, "m_isGhost"))
	{
		g_iLastClass[Client] = GetEntProp(Client, Prop_Send, "m_zombieClass")
		g_iSLastClass[Client] = g_iLastClass[Client];
	}

	return Plugin_Continue;
}

public Action:Timer_NotifyKey(Handle:hTimer, any:Client)
{
	if (IsClientInGame(Client) && !IsFakeClient(Client) && GetClientTeam(Client) == TEAM_INFECTED)
	{
		PrintToChat(Client, PLAYER_MELEE_INGAME, PLAYER_KEYS(g_iZCSelectKey));
	}
}

public Action:Timer_DelayChange(Handle:hTimer, any:Client)
{
	g_bIsChanging[Client] = false;
}

public Action:Timer_SpawnGhostClass(Handle:hTimer, any:Client)
{
	if (!IsClientInGame(Client) || GetClientTeam(Client) != TEAM_INFECTED || g_bRoundEnd)
		return Plugin_Continue;

	if (GetClientHealth(Client) <= 1)
	{
		CreateTimer (ZC_TIMEOFFSET, Timer_SpawnGhostClass, Client);
		return Plugin_Continue;
	}

	if (!IsValidEntity(Client))
		return Plugin_Continue;

	new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");

	if (ZClass == ZC_TANK)
		return Plugin_Continue;

	Sub_DetermineClass(Client, ZClass);

	return Plugin_Continue;
}

public Sub_ResetArrayClass()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iNextClass[i] = 0;
		g_iLastClass[i] = 0;
		g_iSLastClass[i] = 0;
	}
}

public Sub_ReloadConVars()
{
	g_bRespectLimits = GetConVarBool(g_hRespectLimits);
	g_bShowHudPanel = GetConVarBool(g_hShowHudPanel);
	g_bCountFakeBots = GetConVarBool(g_hCountFakeBots);
	g_bSwitchInFinale = GetConVarBool(g_hSwitchInFinale);
	g_bAllowLastClass = GetConVarBool(g_hAllowLastClass);
	g_iZCSelectKey = GetConVarInt(g_hZCSelectKey);
	g_fZCSelectDelay = GetConVarFloat(g_hZCSelectDelay);
}

public Sub_ReloadLimits()
{
	if (g_bRespectLimits)
	{
		for (new i = 1; i <= ZC_TOTAL; i++)
		{
			g_iZVLimits[i] = 0;
			g_iZLimits[i] = 0;
		}

		g_iZVLimits[ZC_SMOKER] = GetConVarInt(FindConVar("z_versus_smoker_limit"));
		g_iZVLimits[ZC_BOOMER] = GetConVarInt(FindConVar("z_versus_boomer_limit"));
		g_iZVLimits[ZC_HUNTER] = GetConVarInt(FindConVar("z_versus_hunter_limit"));
		g_iZVLimits[ZC_SPITTER] = GetConVarInt(FindConVar("z_versus_spitter_limit"));
		g_iZVLimits[ZC_JOCKEY] = GetConVarInt(FindConVar("z_versus_jockey_limit"));
		g_iZVLimits[ZC_CHARGER] = GetConVarInt(FindConVar("z_versus_charger_limit"));

		g_iZLimits[ZC_SMOKER] = GetConVarInt(FindConVar("z_smoker_limit"));
		g_iZLimits[ZC_BOOMER] = GetConVarInt(FindConVar("z_boomer_limit"));
		g_iZLimits[ZC_HUNTER] = GetConVarInt(FindConVar("z_hunter_limit"));
		g_iZLimits[ZC_SPITTER] = GetConVarInt(FindConVar("z_spitter_limit"));
		g_iZLimits[ZC_JOCKEY] = GetConVarInt(FindConVar("z_jockey_limit"));
		g_iZLimits[ZC_CHARGER] = GetConVarInt(FindConVar("z_charger_limit"));

		for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
		{
			g_iZVLimits[ZC_TOTAL] += g_iZVLimits[i];
			g_iZLimits[ZC_TOTAL] += g_iZLimits[i];
		}
	}
}

public ConVarsChanged(Handle:hConvar, const String:oldValue[], const String:newValue[])
{
        Sub_ReloadConVars();
	Sub_ReloadLimits();
}

public Sub_CountInfectedClass(any:ZClass, bool:GetTotal)
{
	new ClassCount, ClassType;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (IsValidEntity(i) && GetClientHealth(i) > 1)
			{
				ClassType = GetEntProp(i, Prop_Send, "m_zombieClass");

				if (GetTotal && ClassType != ZC_TANK)
				{
					if (!g_bCountFakeBots)
					{
						if (!IsFakeClient(i))
							ClassCount++;
					}
						else
							ClassCount++;
				}
				else
				{
					if (ClassType == ZClass)
					{
						if (!g_bCountFakeBots)
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

	return ClassCount;
}

public bool:Sub_CheckPerClassLimits(any:Client, any:ZClass)
{
	new ClassCount = Sub_CountInfectedClass(ZClass, false);

	if (ClassCount < g_iZVLimits[ZClass])
		return true;

        return false;
}

public bool:Sub_CheckAllClassLimits()
{
	for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
	{
		new ClassCount = Sub_CountInfectedClass(i, false);

	        if (ClassCount < g_iZVLimits[i])
        	        return true;
	}

        return false;
}

public Sub_DetermineClass(any:Client, any:ZClass)
{
	switch (ZClass)
	{
		case ZC_SMOKER: g_iNextClass[Client] = ZC_BOOMER;
		case ZC_BOOMER: g_iNextClass[Client] = ZC_HUNTER;
		case ZC_HUNTER: g_iNextClass[Client] = ZC_SPITTER;
		case ZC_SPITTER: g_iNextClass[Client] = ZC_JOCKEY;
		case ZC_JOCKEY: g_iNextClass[Client] = ZC_CHARGER;
		case ZC_CHARGER: g_iNextClass[Client] = ZC_SMOKER;
	}

	CreateTimer(0.01, Timer_DetermineLimits, Client, TIMER_FLAG_NO_MAPCHANGE)
}

public Action:Timer_DetermineLimits(Handle:hTimer, any:Client)
{
	if (g_bRespectLimits)
	{
		new ZTotal = Sub_CountInfectedClass(0, true);

                if (!Sub_CheckAllClassLimits())
                {
                        PrintToChat(Client, PLAYER_LIMITS_UP, ZTotal, g_iZVLimits[ZC_TOTAL]);
                        return;
                }

		for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
		{
			if (g_iNextClass[Client] == i && !Sub_CheckPerClassLimits(Client, g_iNextClass[Client]))
			{
#if _DEBUG
				LogMessage("[+] S_DC: (%N) Next Class Over Limit (%s)", Client, TEAM_CLASS(g_iNextClass[Client]));
#endif
				if (i != ZC_CHARGER)
					g_iNextClass[Client] = i + 1;
				else
					g_iNextClass[Client] = ZC_SMOKER;
			}

			if (!g_bAllowLastClass)
			{
				g_iLastClass[Client] = g_iSLastClass[Client];

				if (g_iNextClass[Client] == i && g_iLastClass[Client] == i && Sub_CheckPerClassLimits(Client, g_iNextClass[Client]))
				{
#if _DEBUG
					LogMessage("[+] S_DC: (%N) Detected Same Class (%s/%s)", Client, TEAM_CLASS(g_iLastClass[Client]), TEAM_CLASS(g_iNextClass[Client]));
#endif
                                        if (ZTotal >= (g_iZVLimits[ZC_TOTAL]-1))
					{
						g_iSLastClass[Client] = g_iLastClass[Client];
						g_iLastClass[Client] = 0;
                                                PrintToChat(Client, PLAYER_CLASSES_UP);
                                        }
					else
					{
		                                if (i != ZC_CHARGER)
        		                                g_iNextClass[Client] = i + 1;
                		                else
                        		                g_iNextClass[Client] = ZC_SMOKER;
					}
				}
			}
		}
#if _DEBUG
		LogMessage("[+] S_DC: (%N) Zombie Class (Last: %s, Next: %s Total: %d)", Client, TEAM_CLASS(g_iLastClass[Client]), TEAM_CLASS(g_iNextClass[Client]), ZTotal);
#endif
		if (!Sub_CheckPerClassLimits(Client, g_iNextClass[Client]) && g_iNextClass[Client] == ZC_SMOKER)
		{
#if _DEBUG
			LogMessage("[+] T_DT: (%N) Looping as (%s) Over Limit.", Client, TEAM_CLASS(g_iNextClass[Client]));
#endif
			CreateTimer(0.01, Timer_DetermineLimits, Client, TIMER_FLAG_NO_MAPCHANGE);
			return;
		}
	}

	RemovePlayerItem(Client, GetPlayerWeaponSlot(Client, 0));
	SDKCall(g_hSetClass, Client, g_iNextClass[Client]);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(Client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(Client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, Client), g_oAbility));
	Hud_ShowLimits(Client);
}

public Hud_ShowLimits(any:Client)
{
	if (!g_bShowHudPanel)
		return;

	if (!IsClientInGame(Client) || GetClientTeam(Client) != TEAM_INFECTED)
		return;

	new Handle:hPanel = CreatePanel();
	decl String:hPanelBuff[1024];

	Format(hPanelBuff, sizeof(hPanelBuff), "(L4D+) Infected Limits");
	DrawPanelText(hPanel, hPanelBuff);
	DrawPanelText(hPanel, " ");

	for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
	{
		Format(hPanelBuff, sizeof(hPanelBuff), "->%d. (%d/%d/%d) %s", i, Sub_CountInfectedClass(i, false), g_iZVLimits[i], g_iZLimits[i], TEAM_CLASS(i));
		DrawPanelText(hPanel, hPanelBuff);
	}

	SendPanelToClient(hPanel, Client, Hud_LimitsPanel, 25);
	CloseHandle(hPanel);
}

public Hud_LimitsPanel(Handle:hMenu, MenuAction:action, param1, param2)
{
	return;
}
