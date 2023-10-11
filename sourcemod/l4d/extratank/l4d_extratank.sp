/**
 * vim: set ts=4 :
 * =============================================================================
 * Extra Tanks 2.0-L4D1 by XBetaAlpha
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

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"0.5"
#define PLUGIN_NAME	"Extra Tanks"

#define CVAR_FLAGS	FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD

new Handle:g_TankHealth = INVALID_HANDLE;
new Handle:g_TankSpawnDelay = INVALID_HANDLE;
new Handle:g_TankTotal = INVALID_HANDLE;

new g_iTankTotal;
new Float:g_fTankPosition[3];

new bool:g_bHealthChanged[MAXPLAYERS+1];
new bool:g_bTankInPlay[MAXPLAYERS+1];
new bool:g_bFireImmunity[MAXPLAYERS+1];
new bool:g_bIsFirstTank = false;
new bool:g_bRoundEnd = false;

public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = "XBetaAlpha",
	description = "Spawns Extra Tanks (Including Prohibited Maps).",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
        CreateConVar("extratank_version", PLUGIN_VERSION, "Version of Extra Tanks on this server", CVAR_FLAGS);

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("map_transition", Event_RoundStart);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("finale_win", Event_RoundEnd);
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	//HookEvent("versus_marker_reached", Event_VersusMarker);

	g_TankHealth = CreateConVar("l4d_tank_hp","9000","Tank Health Setting", FCVAR_PLUGIN, true, 0.01, true, 65535.0);
	g_TankSpawnDelay = CreateConVar("l4d_tank_spawndelay", "2.0", "Tank Spawn Delay", FCVAR_PLUGIN, true, 0.1, true, 60.0);
	g_TankTotal = CreateConVar("l4d_tank_total", "2", "Tank Count", FCVAR_PLUGIN, true, 1.0, true, 10.0);
}

public OnMapStart()
{
        ResetHealthChanged();
}

public OnMapEnd()
{
	ResetHealthChanged();
}

public OnClientAuthorized(client, const String:auth[])
{
	if (!IsFakeClient(client))
		return;

	decl String:name[256];
	GetClientName(client, name, sizeof(name));

	if (StrEqual(name, "Tank") && CountTanks() == 0)
	{
		OnClient_TankSpawn(client);
	}
}

public Action:OnClient_TankSpawn(any:client)
{
	SetTankHealth(client);
	g_iTankTotal = GetConVarInt(g_TankTotal);

	new Float:TankSpawnDelay = GetConVarFloat(g_TankSpawnDelay);
	new Float:TankDelay = GetConVarFloat(FindConVar("director_tank_lottery_selection_time")) + TankSpawnDelay;

	CreateTimer(1.0, Timer_ShowInfectedTankHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(TankDelay, SpawnExtraTank, client, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

public Action:SpawnExtraTank(Handle:timer, any:client)
{
        if (g_bRoundEnd)
                return;

        if (CountTanks() >= g_iTankTotal)
                return;

	new FakeClient = Sub_CreateFakeClient();

	if (FakeClient != 0)
	{
		new flags = GetCommandFlags("z_spawn");
		SetCommandFlags("z_spawn", flags & ~FCVAR_CHEAT);
		FakeClientCommand(FakeClient, "z_spawn tank auto")
		SetCommandFlags("z_spawn", flags);

		if (IsFakeClient(FakeClient))
			KickClient(FakeClient);
	}

	CreateTimer(1.5, CheckSpawn, 0);
}

public Action:CheckSpawn(Handle:timer, any:client)
{
	if (CountTanks() <= g_iTankTotal)
	{
		CreateTimer(0.5, SpawnExtraTank, 0);
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
        g_iTankTotal = 0;
	g_bIsFirstTank = false;
	g_bRoundEnd = false;
        ResetHealthChanged();

	return Plugin_Continue;
}

public Action:Event_FinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetHealthChanged();
}

/*public Action:Event_VersusMarker(Handle:event, const String:name[], bool:dontBroadcast)
{
	new marker = GetEventInt(event, "marker");

	LogMessage("[+] E_VM: Versus Round (%% completed): %d%", marker);
}*/

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = true;
        ResetHealthChanged();
}

public Action:Event_PlayerDeath (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

	if (client == 0 || !IsClientConnected(client) || !IsClientInGame(client))
		return Plugin_Continue;

	if (!IsValidEntity(client))
		return Plugin_Continue;

	decl String:stringclass[32];
	GetClientModel(client, stringclass, 32);

	if (StrContains(stringclass, "hulk", false) != -1)
	{
		g_bHealthChanged[client] = true;
		g_bTankInPlay[client] = false;
		g_bFireImmunity[client] = false;
		g_bIsFirstTank = false;
		CreateTimer(3.0, CheckTanks, client);
	}

	return Plugin_Continue;
}

public Action:CheckTanks(Handle:timer, Handle:client)
{
	if (CountTanks() <= 0)
	{
		ResetHealthChanged();
	}
}

public CountTanks()
{
	if (g_bRoundEnd)
		return 0;

	new TanksCount = 0;
	decl String:stringclass[32];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
		{
			GetClientModel(i, stringclass, 32);
			if (StrContains(stringclass, "hulk", false) != -1)
			{
				TanksCount++;

				if (!g_bHealthChanged[i])
				{
					SetTankHealth(i);
				}
			}
		}
	}

	return TanksCount;
}

public Action:SetTankHealth(client)
{
        if (!IsValidEntity(client))
                return;

	new _iTankHealth, _R, _G, _B;

	_iTankHealth = GetConVarInt(g_TankHealth);

        if (_iTankHealth > 65535)
		_iTankHealth = 65535;

	SetEntProp(client, Prop_Send, "m_iHealth", _iTankHealth);
	SetEntProp(client, Prop_Send, "m_iMaxHealth", _iTankHealth);

	_R = GetRandomInt(0, 255);
	_G = GetRandomInt(0, 255);
	_B = GetRandomInt(0, 255);

	// 16, 224, 84

        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, _R, _G, _B, 255);

	if (!IsFakeClient(client))
	{
	        if (!g_bIsFirstTank)
		{
			g_bIsFirstTank = true;
			GetEntPropVector(client, Prop_Data, "m_vecOrigin", g_fTankPosition);
		        LogMessage("[+] Get Tank Vector: %N (%d) (%f)", client, client, g_fTankPosition);
		}
		else
		{
			SetEntPropVector(client, Prop_Data, "m_vecOrigin", g_fTankPosition);
			LogMessage("[+] Set Tank Vector: %N (%d) (%f)", client, client, g_fTankPosition);
		}

		LogMessage("[+] STH: (%d/%d/%d) Player %N is a Tank (HP: %d)", _R, _G, _B, client, _iTankHealth);
	}

	g_bHealthChanged[client] = true;
}

public ResetHealthChanged()
{
	for (new i = 1 ; i <= MaxClients ; i++)
	{
		g_bHealthChanged[i] = false;
		g_bTankInPlay[i] = false;
		g_bFireImmunity[i] = false;
	}

	g_bIsFirstTank = false;
}

public Sub_CountTeam(any:Team)
{
	new TeamCount;

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == Team)
                {
			if (!IsFakeClient(i))
				TeamCount++;
		}
        }

	return TeamCount;
}

public Action:Timer_ShowInfectedTankHud(Handle:hTimer, any:client)
{
        if (CountTanks() == 0 || g_bRoundEnd)
        {
                return Plugin_Stop;
        }

        decl String:_sBuffer [150];
        decl String:stringclass[32];
        new Handle:_hInfectedTankHud;

        _hInfectedTankHud = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
        SetPanelTitle(_hInfectedTankHud, "Infected Tanks:");
        DrawPanelText(_hInfectedTankHud, " ");

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 3)
                {
			GetClientModel(i, stringclass, 32);
			if (IsPlayerAlive(i) && StrContains(stringclass, "hulk", false) != -1)
                        {
				if (!IsFakeClient(i))
	                                Format(_sBuffer, sizeof(_sBuffer), "%N. (HP: %i)", i, GetClientHealth(i));
				else
					Format(_sBuffer, sizeof(_sBuffer), "Tank is coming...");

                                DrawPanelItem(_hInfectedTankHud, _sBuffer);
                        }
                }
        }

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
                {
                        if (GetClientTeam(i) == 2)
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

Sub_CreateFakeClient()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			return i;
		}
	}

        new FakeClient = CreateFakeClient("FakeClient");

        if (FakeClient != 0)
                return FakeClient;

	return 0;
}

