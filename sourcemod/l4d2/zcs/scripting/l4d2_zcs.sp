/**
 * vim: set ts=4 :
 * =============================================================================
 * Zombie Character Select 0.8.7b by XBetaAlpha
 *
 * Allows a player on the infected team to change their infected class.
 * Based on the original Infected Character Select by Crimson_Fox.
 *
 * SourceMod (C)2004-2010 AlliedModders LLC.  All rights reserved.
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

#define PLUGIN_VERSION		"0.8.7b"
#define _DEBUG			0

#define ZC_SMOKER		1
#define ZC_BOOMER		2
#define ZC_HUNTER		3
#define ZC_SPITTER		4
#define ZC_JOCKEY		5
#define ZC_CHARGER		6
#define ZC_WITCH		7
#define ZC_TANK			8
#define ZC_NOTINFECTED		9

#define ZC_TOTAL		7
#define ZC_LIMITSIZE		ZC_TOTAL + 1
#define ZC_INDEXSIZE		ZC_TOTAL + 4
#define ZC_TIMEOFFSET		0.2

#define TEAM_SPECTATORS		1
#define TEAM_SURVIVORS		2
#define TEAM_INFECTED		3

#define PLATFORM_WINDOWS	1
#define PLATFORM_LINUX		2

#define PLAYER_KEY_MSG_DELAY	3.0
#define PLAYER_LOCK_MSG_DELAY	3.5
#define PLAYER_MELEE_INGAME	"\x04Press the %s key as ghost to change zombie class."
#define PLAYER_LIMITS_UP	"\x04Limits reached. Choose current class or wait. (%d/%d)"
#define PLAYER_COOLDOWN_WAIT	"\x04Waiting for %s class to become available. (%d/%d)"
#define PLAYER_CLASSES_UP_ALLOW	"\x04No more classes available. Last class allowed."
#define PLAYER_CLASSES_UP_DENY	"\x04No more classes available. Choose current class or wait."
#define PLAYER_NOTIFY_LOCK	"\x04If class is not chosen within %.0fs, changing will be disabled."
#define PLAYER_SWITCH_LOCK	"\x04Timer: %.0fs up. Selection disabled. Please choose current class."

#define TEAM_CLASS(%1)		(%1 == 1 ? "Smoker" : (%1 == 2 ? "Boomer" : (%1 == 3 ? "Hunter" :(%1 == 4 ? "Spitter" : (%1 == 5 ? "Jockey" : (%1 == 6 ? "Charger" : (%1 == 7 ? "Tank" : "None")))))))
#define SELECT_KEY(%1)		(%1 == 1 ? IN_ATTACK2 : (%1 == 2 ? IN_RELOAD : 0))
#define PLAYER_KEYS(%1)		(%1 == 1 ? "MELEE" : (%1 == 2 ? "RELOAD" : "None"))

new Handle:g_hSetClass		= INVALID_HANDLE;
new Handle:g_hCreateAbility	= INVALID_HANDLE;
new Handle:g_hGameConf		= INVALID_HANDLE;

new Handle:g_hRespectLimits 	= INVALID_HANDLE;
new Handle:g_hShowHudPanel 	= INVALID_HANDLE;
new Handle:g_hCountFakeBots 	= INVALID_HANDLE;
new Handle:g_hSwitchInFinale 	= INVALID_HANDLE;
new Handle:g_hAllowLastClass	= INVALID_HANDLE;
new Handle:g_hAllowLastOnLimit	= INVALID_HANDLE;
new Handle:g_hZCSelectKey	= INVALID_HANDLE;
new Handle:g_hZCSelectDelay 	= INVALID_HANDLE;
new Handle:g_hZCCooldownEnable	= INVALID_HANDLE;
new Handle:g_hZCCooldownDelay	= INVALID_HANDLE;
new Handle:g_hZCLockDelay	= INVALID_HANDLE;

new Handle:g_hLockTimer[MAXPLAYERS+1]		= {INVALID_HANDLE,...};
new Handle:g_hAllowClassTimer[ZC_INDEXSIZE]	= {INVALID_HANDLE,...};

new bool:g_bIsHoldingMelee[MAXPLAYERS+1]	= {false,...};
new bool:g_bIsChanging[MAXPLAYERS+1]		= {false,...};
new bool:g_bSwitchLock[MAXPLAYERS+1]		= {false,...};
new bool:g_bHasMaterialised[MAXPLAYERS+1]	= {false,...};

new bool:g_bRespectLimits	= false;
new bool:g_bShowHudPanel	= false;
new bool:g_bCountFakeBots	= false;
new bool:g_bSwitchInFinale	= false;
new bool:g_bAllowLastClass	= false;
new bool:g_bAllowLastOnLimit	= false;
new bool:g_bZCCooldownEnable	= false;
new bool:g_bSwitchDisabled	= false;
new bool:g_bRoundStart		= false;
new bool:g_bRoundEnd		= false;
new bool:g_bLeftSafeRoom	= false;

new g_iZCSelectKey		= 0;
new g_oAbility			= 0;
new Float:g_fZCSelectDelay	= 0.0;
new Float:g_fZCCooldownDelay	= 0.0;
new Float:g_fZCLockDelay	= 0.0;

new g_iLastClass[MAXPLAYERS+1]	= {0,...};
new g_iNextClass[MAXPLAYERS+1]	= {0,...};
new g_iSLastClass[MAXPLAYERS+1] = {0,...};
new g_iZVLimits[ZC_LIMITSIZE]	= {0,...};
new g_iZLimits[ZC_LIMITSIZE]	= {0,...};
new g_iAllowClass[ZC_INDEXSIZE] = {1,...};

public Plugin:myinfo =
{
	name = "Zombie Character Select",
	author = "XBetaAlpha",
	description = "Allows infected team players to change their class in ghost mode. (Versus Only)",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1016671"
}

public OnPluginStart()
{
	Sub_CheckGameName("left4dead2");

	CreateConVar("zcs_version", PLUGIN_VERSION, "Zombie Character Select version.", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_hRespectLimits	= CreateConVar("zcs_respect_limits", "1", "Respect server configured z_versus limits.", FCVAR_PLUGIN);
	g_hShowHudPanel		= CreateConVar("zcs_show_hud_panel", "0", "Display infected class limits panel.", FCVAR_PLUGIN);
	g_hCountFakeBots	= CreateConVar("zcs_count_fake_bots", "0", "Include fake infected bots in limits.", FCVAR_PLUGIN);
	g_hSwitchInFinale	= CreateConVar("zcs_switch_in_finale", "1", "Allow infected class switch at finale stages.", FCVAR_PLUGIN);
	g_hAllowLastClass	= CreateConVar("zcs_allow_last_class", "0", "Allow player to select previous infected class.", FCVAR_PLUGIN);
	g_hAllowLastOnLimit	= CreateConVar("zcs_allow_last_on_limit", "0", "Allow player to select previous infected class when limits are up.", FCVAR_PLUGIN);
	g_hZCSelectKey		= CreateConVar("zcs_zcselect_key", "1", "Key binding for infected class selection. (1=MELEE, 2=RELOAD)", FCVAR_PLUGIN, true, 1.0, true, 2.0);
	g_hZCSelectDelay	= CreateConVar("zcs_zcselect_delay", "0.5", "Infected class switch delay in (s).", FCVAR_PLUGIN, true, 0.1, true, 10.0);
	g_hZCCooldownEnable	= CreateConVar("zcs_zccooldown_enable", "0", "Infected class cooldown timer enable. EXPERIMENTAL (0=Disable timer)", FCVAR_PLUGIN);
	g_hZCCooldownDelay	= CreateConVar("zcs_zccooldown_delay", "0", "Infected class cooldown timer delay in (s). EXPERIMENTAL (0=Use director spawn time)", FCVAR_PLUGIN, true, 0.0, true, 30.0);
	g_hZCLockDelay		= CreateConVar("zcs_zclock_delay", "0", "Time before infected class switching is locked in (s). EXPERIMENTAL (0=Disable lock)", FCVAR_PLUGIN, true, 0.0, true, 600.0);

	HookConVarChange(g_hRespectLimits, Sub_ConVarsChanged);
	HookConVarChange(g_hShowHudPanel, Sub_ConVarsChanged);
	HookConVarChange(g_hCountFakeBots, Sub_ConVarsChanged);
	HookConVarChange(g_hSwitchInFinale, Sub_ConVarsChanged);
	HookConVarChange(g_hAllowLastClass, Sub_ConVarsChanged);
	HookConVarChange(g_hAllowLastOnLimit, Sub_ConVarsChanged);
	HookConVarChange(g_hZCSelectKey, Sub_ConVarsChanged);
	HookConVarChange(g_hZCSelectDelay, Sub_ConVarsChanged);
	HookConVarChange(g_hZCCooldownEnable, Sub_ConVarsChanged);
	HookConVarChange(g_hZCCooldownDelay, Sub_ConVarsChanged);
	HookConVarChange(g_hZCLockDelay, Sub_ConVarsChanged);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
        HookEvent("finale_win", Event_RoundEnd);
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("ghost_spawn_time", Event_GhostSpawnTime);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("door_open", Event_DoorOpen);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("tank_frustrated", Event_TankFrustrated);

	Sub_HookGameData("l4d2_zcs");
	AutoExecConfig(true, "l4d2_zcs");
}

public OnConfigsExecuted()
{
	Sub_ReloadConVars();
	Sub_ReloadLimits();
}

public OnClientDisconnect(Client)
{
	if (IsFakeClient(Client))
		return;

	Sub_ClearClassLock(Client);
	g_bHasMaterialised[Client] = false;
}

public Action:Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_bRoundStart)
		return Plugin_Continue;

	g_bRoundStart = true;
	g_bRoundEnd = false;
	g_bSwitchDisabled = false;
	g_bLeftSafeRoom = false;

	Sub_ClearArrays();

	if (g_bShowHudPanel)
		CreateTimer(1.0, Timer_ShowHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_bRoundEnd)
		return Plugin_Continue;

	g_bRoundStart = false;
	g_bRoundEnd = true;

	return Plugin_Continue;
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
	new OldTeam = GetEventInt(hEvent, "oldteam");

        if (Client != 0 && OldTeam == TEAM_INFECTED)
		Sub_ClearClassLock(Client);

	if (Client == 0 || NewTeam != TEAM_INFECTED)
		return Plugin_Continue;

	CreateTimer(PLAYER_KEY_MSG_DELAY, Timer_NotifyKey, Client, TIMER_FLAG_NO_MAPCHANGE);

	g_bHasMaterialised[Client] = false;
	Sub_ClearClassLock(Client);
	Sub_CheckClassLock(Client);

	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

        if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client) || GetClientTeam(Client) != TEAM_INFECTED)
		return Plugin_Continue;

	if (!Sub_IsTank(Client))
		Sub_ClearClassLock(Client);

	if (g_bZCCooldownEnable)
	{
		new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");

		if ((ZClass >= ZC_SMOKER) && (ZClass <= ZC_CHARGER))
		{
			if (g_iAllowClass[ZClass] != 0 && g_hAllowClassTimer[ZClass] == INVALID_HANDLE)
			{
				Sub_DebugPrint("[+] E_PD: (%N) Class (%s) is cooling down. (g_iAllowClass=0)", Client, TEAM_CLASS(ZClass));
				g_iAllowClass[ZClass] = 0;
			}
		}
	}

	g_bHasMaterialised[Client] = false;

	return Plugin_Continue;
}

public Action:Event_GhostSpawnTime(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client) || g_bRoundEnd)
		return Plugin_Continue;

	new Float:SpawnTime = GetEventFloat(hEvent, "spawntime");
	CreateTimer(SpawnTime - ZC_TIMEOFFSET, Timer_SpawnGhostClass, Client, TIMER_FLAG_NO_MAPCHANGE);
	Sub_DebugPrint("[+] E_GST: (%N) Will spawn as a ghost in %0.fs.", Client, SpawnTime);
	g_bHasMaterialised[Client] = false;

	if (g_bZCCooldownEnable)
	{
       		new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");

		if ((ZClass >= ZC_SMOKER) && (ZClass <= ZC_CHARGER))
		{
			if (g_iAllowClass[ZClass] != 1 && g_hAllowClassTimer[ZClass] == INVALID_HANDLE)
			{
				if (g_fZCCooldownDelay > 0)
					SpawnTime = g_fZCCooldownDelay;

				Sub_DebugPrint("[+] E_GST: (%N) Class (%s) will be released in %.0fs. (g_iAllowClass=0)", Client, TEAM_CLASS(ZClass), SpawnTime);
				g_hAllowClassTimer[ZClass] = CreateTimer(SpawnTime, Timer_ReleaseClass, ZClass, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_PlayerLeftStartArea(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_bLeftSafeRoom || g_bRoundEnd)
		return Plugin_Continue;

	g_bLeftSafeRoom = true;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			Sub_CheckClassLock(i);
	}

	return Plugin_Continue;
}

public Action:Event_DoorOpen(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
        if (g_bLeftSafeRoom || g_bRoundEnd)
                return Plugin_Continue;

	if (!GetEventBool(hEvent, "checkpoint"))
		return Plugin_Continue;

	g_bLeftSafeRoom = true;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
			Sub_CheckClassLock(i);
	}

        return Plugin_Continue;
}

public Action:Event_TankSpawn(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
        if (g_bRoundEnd)
                return Plugin_Continue;

	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	Sub_ClearClassLock(Client);

	return Plugin_Continue;
}

public Action:Event_TankFrustrated(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (g_bRoundEnd)
		return Plugin_Continue;

	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	Sub_DebugPrint("[+] E_TF: Tank is frustrated, player (%N) is being switched back to SI.", Client);
	g_bHasMaterialised[Client] = false;
	CreateTimer(0.01, Timer_SpawnGhostClass, Client, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (Client == 0 || !IsValidEntity(Client) || !IsClientInGame(Client) || IsFakeClient(Client) || Sub_IsTank(Client))
		return Plugin_Continue;

	if (GetEntProp(Client, Prop_Send, "m_isGhost") && !GetEntProp(Client, Prop_Send,"m_isCulling"))
	{
		if (!g_bRoundEnd && !g_bSwitchDisabled && !g_bSwitchLock[Client] && !g_bHasMaterialised[Client])
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
				}
			}

			else
				g_bIsHoldingMelee[Client] = false;
		}
	}

	if (buttons & IN_ATTACK && GetEntProp(Client, Prop_Send, "m_isGhost"))
		CreateTimer(g_fZCSelectDelay, Timer_SelectDelay, Client, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action:Timer_SelectDelay(Handle:hTimer, any:Client)
{
	if (!IsValidEntity(Client) || !IsClientInGame(Client))
		return Plugin_Continue;

	if (!GetEntProp(Client, Prop_Send, "m_isGhost"))
	{
		g_iLastClass[Client] = GetEntProp(Client, Prop_Send, "m_zombieClass");
		g_iSLastClass[Client] = g_iLastClass[Client];
		g_bHasMaterialised[Client] = true;
		Sub_ClearClassLock(Client);
	}

	return Plugin_Continue;
}

public Action:Timer_NotifyKey(Handle:hTimer, any:Client)
{
	if (IsClientInGame(Client) && !IsFakeClient(Client) && GetClientTeam(Client) == TEAM_INFECTED)
	{
		if (!Sub_IsTank(Client))
			PrintToChat(Client, PLAYER_MELEE_INGAME, PLAYER_KEYS(g_iZCSelectKey));
	}
}

public Action:Timer_NotifyLock(Handle:hTimer, any:Client)
{
	if (IsClientInGame(Client) && !IsFakeClient(Client) && GetClientTeam(Client) == TEAM_INFECTED)
	{
		if (!Sub_IsTank(Client))
			PrintToChat(Client, PLAYER_NOTIFY_LOCK, g_fZCLockDelay);
	}
}

public Action:Timer_DelayChange(Handle:hTimer, any:Client)
{
	g_bIsChanging[Client] = false;
}

public Action:Timer_ReleaseClass(Handle:hTimer, any:ZClass)
{
	if (g_iAllowClass[ZClass] != 1)
	{
		g_iAllowClass[ZClass] = 1;
		Sub_DebugPrint("[+] T_UC: Class (%s) is now released. (g_iAllowClass=1)", TEAM_CLASS(ZClass));
		g_hAllowClassTimer[ZClass] = INVALID_HANDLE;
	}
}

public Action:Timer_SpawnGhostClass(Handle:hTimer, any:Client)
{
	if (!IsClientInGame(Client) || GetClientTeam(Client) != TEAM_INFECTED || g_bRoundEnd)
		return Plugin_Continue;

	if (!IsPlayerAlive(Client))
	{
		Sub_DebugPrint("[+] T_SGC: (%N) Waiting for player to become alive.", Client);
		CreateTimer(0.05, Timer_SpawnGhostClass, Client, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}

	if (!IsValidEntity(Client))
		return Plugin_Continue;

	if (!GetEntProp(Client, Prop_Send, "m_isGhost"))
		return Plugin_Continue;

	new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");

	if (!g_bAllowLastClass)
		Sub_DetermineClass(Client, ZClass);
	else
	{
		if (ZClass == g_iLastClass[Client])
			Sub_DetermineClass(Client, ZClass);
	}

	Sub_CheckClassLock(Client);
	Sub_DebugPrint("[+] S_DC: Current Entity Count: %d (Total: %d)", GetEntityCount(), GetMaxEntities());

	return Plugin_Continue;
}

public Action:Timer_SwitchLock(Handle:hTimer, any:Client)
{
	if (!IsValidEntity(Client) || !IsClientInGame(Client) || GetClientTeam(Client) != TEAM_INFECTED)
		return Plugin_Continue;

	if (g_fZCLockDelay > 0 && g_bLeftSafeRoom && !Sub_IsTank(Client))
	{
		if (GetEntProp(Client, Prop_Send, "m_isGhost"))
		{
			PrintToChat(Client, PLAYER_SWITCH_LOCK, g_fZCLockDelay);
			g_bSwitchLock[Client] = true;
		}
	}

	return Plugin_Continue;
}

public Action:Timer_ShowHud(Handle:hTimer)
{
	if (g_bRoundEnd)
		return Plugin_Stop;

	Hud_ShowLimits();

	return Plugin_Continue;
}

public Sub_ClearClassLock(any:Client)
{
	if (g_fZCLockDelay > 0 && g_bLeftSafeRoom)
	{
		if (g_hLockTimer[Client] != INVALID_HANDLE)
		{
			if (!g_bSwitchLock[Client])
				CloseHandle(g_hLockTimer[Client]);

			g_hLockTimer[Client] = INVALID_HANDLE;
			g_bSwitchLock[Client] = false;
			Sub_DebugPrint("[+] S_CCL: (%N) Clearing lock timer (%.0fs).", Client, GetConVarFloat(g_hZCLockDelay));
		}
	}
}

public Sub_CheckClassLock(any:Client)
{
	if (g_fZCLockDelay > 0 && g_bLeftSafeRoom && !Sub_IsTank(Client) && IsPlayerAlive(Client))
	{
		if (g_hLockTimer[Client] == INVALID_HANDLE)
		{
			Sub_DebugPrint("[+] T_SGC: (%N) Creating lock timer (%.0fs).", Client, GetConVarFloat(g_hZCLockDelay));
			CreateTimer(PLAYER_LOCK_MSG_DELAY, Timer_NotifyLock, Client, TIMER_FLAG_NO_MAPCHANGE);
			g_hLockTimer[Client] = CreateTimer(g_fZCLockDelay, Timer_SwitchLock, Client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Sub_ClearArrays()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iNextClass[i] = 0;
		g_iLastClass[i] = 0;
		g_iSLastClass[i] = 0;
		g_bSwitchLock[i] = false;
		g_bIsHoldingMelee[i] = false;
		g_bIsChanging[i] = false;
		g_bHasMaterialised[i] = false;
		g_hLockTimer[i] = INVALID_HANDLE;
	}

	if (g_bZCCooldownEnable)
	{
		for (new i = 1; i <= ZC_TOTAL; i++)
		{
			g_hAllowClassTimer[i] = INVALID_HANDLE;
			g_iAllowClass[i] = 1;
		}
	}
}

public Sub_ReloadConVars()
{
	g_bRespectLimits = GetConVarBool(g_hRespectLimits);
	g_bShowHudPanel = GetConVarBool(g_hShowHudPanel);
	g_bCountFakeBots = GetConVarBool(g_hCountFakeBots);
	g_bSwitchInFinale = GetConVarBool(g_hSwitchInFinale);
	g_bAllowLastClass = GetConVarBool(g_hAllowLastClass);
	g_bAllowLastOnLimit = GetConVarBool(g_hAllowLastOnLimit);
	g_iZCSelectKey = GetConVarInt(g_hZCSelectKey);
	g_fZCSelectDelay = GetConVarFloat(g_hZCSelectDelay);
	g_bZCCooldownEnable = GetConVarBool(g_hZCCooldownEnable);
        g_fZCCooldownDelay = GetConVarFloat(g_hZCCooldownDelay);
	g_fZCLockDelay = GetConVarFloat(g_hZCLockDelay);
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

public Sub_HookGameData(String:GameDataFile[])
{
	g_hGameConf = LoadGameConfigFile(GameDataFile);

	if (g_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetClass = EndPrepSDKCall();

		if (g_hSetClass == INVALID_HANDLE)
			SetFailState("[+] S_HGD: Error: Unable to find SetClass signature.");

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hCreateAbility = EndPrepSDKCall();

		if (g_hCreateAbility == INVALID_HANDLE)
			SetFailState("[+] S_HGD: Error: Unable to find CreateAbility signature.");

		new Platform = GameConfGetOffset(g_hGameConf, "Platform");

		if (Platform == PLATFORM_WINDOWS)
			g_oAbility = 0x390;
		else
			g_oAbility = 0x3a4;

		CloseHandle(g_hGameConf);
	}
	else
		SetFailState("[+] S_HGD: Error: Unable to load gamedata file, exiting.");
}

public Sub_ConVarsChanged(Handle:hConVar, const String:oldValue[], const String:newValue[])
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
			if (IsValidEntity(i) && IsPlayerAlive(i))
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

public bool:Sub_CheckPerClassLimits(any:ZClass)
{
	new ClassCount = Sub_CountInfectedClass(ZClass, false);

	if (g_bZCCooldownEnable)
	{
		if (g_iAllowClass[ZClass] != 1)
		{
			Sub_DebugPrint("[+] S_CPCL: Class (%s) cannot be selected while cooling down. Count Raised (%d/%d)", TEAM_CLASS(ZClass), ClassCount, ClassCount + 1);
			ClassCount += 1;
		}
	}

	if (ClassCount < g_iZVLimits[ZClass])
		return true;

	return false;
}

public bool:Sub_CheckAllClassLimits(any:ZClass)
{
	for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
	{
		new ClassCount = Sub_CountInfectedClass(i, false);

		if (g_bZCCooldownEnable)
		{
			if (g_iAllowClass[i] != 1)
				ClassCount += 1;
		}

		if (ZClass == 0)
		{
	        	if (ClassCount < g_iZVLimits[i])
        		        return true;
		}

		else
		{
			if (ClassCount < g_iZVLimits[i] && ZClass != i)
				return true;
		}
	}

	return false;
}

public bool:Sub_IsTank(any:Client)
{
	new ZClass = GetEntProp(Client, Prop_Send, "m_zombieClass");

	if (ZClass == ZC_TANK)
		return true;

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
		case ZC_TANK: return;
	}

	if (g_bRespectLimits)
	{
		do
		{
			if (Sub_IsTank(Client))
		                return;

			new ZTotal = Sub_CountInfectedClass(0, true);

			if (!Sub_CheckAllClassLimits(0))
			{
				if (ZTotal < g_iZVLimits[ZC_TOTAL])
					PrintToChat(Client, PLAYER_COOLDOWN_WAIT, TEAM_CLASS(g_iLastClass[Client]), ZTotal, g_iZVLimits[ZC_TOTAL]);
				else
					PrintToChat(Client, PLAYER_LIMITS_UP, ZTotal, g_iZVLimits[ZC_TOTAL]);

				Sub_DebugPrint("[+] T_DL: (%N) Player limits are up. (%d/%d)", Client, ZTotal, g_iZVLimits[ZC_TOTAL]);

				return;
			}

			for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
			{
				if (g_iNextClass[Client] == i && !Sub_CheckPerClassLimits(g_iNextClass[Client]))
				{
					Sub_DebugPrint("[+] S_DL: (%N) Next Class Over Limit (%s)", Client, TEAM_CLASS(g_iNextClass[Client]));
					g_iNextClass[Client] = i < ZC_CHARGER ? i + 1 : ZC_SMOKER;
				}

				if (!g_bAllowLastClass)
				{
					if (Sub_CheckLastClass(Client, i) != 0)
						return;
				}
			}

			Sub_DebugPrint("[+] S_DL: (%N) Zombie Class (Last: %s, Next: %s Total: %d)", Client, TEAM_CLASS(g_iLastClass[Client]), TEAM_CLASS(g_iNextClass[Client]), ZTotal);

			if (!Sub_CheckPerClassLimits(g_iNextClass[Client]))
				Sub_DebugPrint("[+] T_DL: (%N) Looping as (%s) Over Limit.", Client, TEAM_CLASS(g_iNextClass[Client]));
		}
		while (!Sub_CheckPerClassLimits(g_iNextClass[Client]));
	}

	new WeaponIndex = GetPlayerWeaponSlot(Client, 0);
	RemovePlayerItem(Client, WeaponIndex);
	RemoveEdict(WeaponIndex);
	SDKCall(g_hSetClass, Client, g_iNextClass[Client]);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(Client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(Client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, Client), g_oAbility));

	return;
}

public Sub_CheckLastClass(any:Client, any:ZClass)
{
	g_iLastClass[Client] = g_iSLastClass[Client];

	if (g_iNextClass[Client] == ZClass && g_iLastClass[Client] == ZClass)
	{
		Sub_DebugPrint("[+] S_DL: (%N) Detected Same Class (%s/%s)", Client, TEAM_CLASS(g_iLastClass[Client]), TEAM_CLASS(g_iNextClass[Client]));

		if (!Sub_CheckAllClassLimits(g_iLastClass[Client]))
		{
			if (g_bAllowLastOnLimit)
			{
				PrintToChat(Client, PLAYER_CLASSES_UP_ALLOW);
				Sub_DebugPrint("[+] S_DL: (%N) Player classes are up. Last class: %s allowed.", Client, TEAM_CLASS(g_iLastClass[Client]));
				g_iSLastClass[Client] = g_iLastClass[Client];
				g_iLastClass[Client] = 0;

				return 0;
			}

			else
			{
				PrintToChat(Client, PLAYER_CLASSES_UP_DENY);
				Sub_DebugPrint("[+] S_DL: (%N) Player classes are up. No more classes allowed.", Client);

				return 1;
			}
		}

		else
			g_iNextClass[Client] = ZClass < ZC_CHARGER ? ZClass + 1 : ZC_SMOKER;
	}

	return 0;
}

public Sub_CheckGameName(String:GameInput[])
{
	decl String:Game_Name[64];
	GetGameFolderName(Game_Name, sizeof(Game_Name));

	if (!StrEqual(Game_Name, GameInput, false))
		SetFailState("[+] S_CGN: Error: Plugin supports Left 4 Dead 2 only, exiting.");
}

public Sub_DebugPrint(const String:Message[], any:...)
{
	#if _DEBUG
	decl String:DebugBuff[128];
	VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
	LogMessage(DebugBuff);
	#endif
}

public Hud_ShowLimits()
{
	if (!g_bShowHudPanel)
		return;

	new Handle:hPanel = CreatePanel();
	decl String:hPanelBuff[1024];
	decl String:sCooldownSymbol[4] = "";

	Format(hPanelBuff, sizeof(hPanelBuff), "(L4D+) Infected Limits");
	DrawPanelText(hPanel, hPanelBuff);
	DrawPanelText(hPanel, " ");

	for (new i = ZC_SMOKER; i <= ZC_CHARGER; i++)
	{
		sCooldownSymbol = g_iAllowClass[i] != 1 ? "(C)" : "   ";
		Format(hPanelBuff, sizeof(hPanelBuff), "->%d. (%d/%d/%d) %s %s", i, Sub_CountInfectedClass(i, false), g_iZVLimits[i], g_iZLimits[i], TEAM_CLASS(i), sCooldownSymbol);
		DrawPanelText(hPanel, hPanelBuff);
	}

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
                {
			if (GetClientTeam(i) == TEAM_INFECTED)
                        {
                                if ((GetClientMenu(i) == MenuSource_RawPanel) || (GetClientMenu(i) == MenuSource_None))
                                {
                                        SendPanelToClient(hPanel, i, Hud_LimitsPanel, 1);
                                }
                        }
                }
        }

	CloseHandle(hPanel);
}

public Hud_LimitsPanel(Handle:hMenu, MenuAction:action, param1, param2)
{
	return;
}
