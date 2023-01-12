#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"0.5"
#define PLUGIN_NAME	"Extra Tanks"

#define CVAR_FLAGS	FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD

new Handle:g_TankHealth = INVALID_HANDLE;
new Handle:g_TankSpawnDelay = INVALID_HANDLE;
new Handle:g_TankTotal = INVALID_HANDLE;

new g_iTankTotal;
new g_iTankSpawnTime;
new Float:g_fTankPosition[3];

new bool:g_bHealthChanged[MAXPLAYERS+1];
new bool:g_bTankInPlay[MAXPLAYERS+1];
new bool:g_bFireImmunity[MAXPLAYERS+1];
new bool:g_bPlayerDisconnected[MAXPLAYERS+1];
new bool:g_bIsFirstTank = false;
new bool:g_bRoundEnd = false;

new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:g_hZombieAbortControl = INVALID_HANDLE;

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
	HookEvent("versus_marker_reached", Event_VersusMarker);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_disconnect", Event_PlayerDisconnect);

	g_TankHealth = CreateConVar("l4d_tank_hp","7000","Tank Health Setting", FCVAR_PLUGIN, true, 0.01, true, 65535.0);
	g_TankSpawnDelay = CreateConVar("l4d_tank_spawndelay", "1.0", "Tank Spawn Delay", FCVAR_PLUGIN, true, 0.1, true, 60.0);
	g_TankTotal = CreateConVar("l4d_tank_total", "2", "Tank Count", FCVAR_PLUGIN, true, 1.0, true, 10.0);

	g_hGameConf = LoadGameConfigFile("l4d2_plus");

	if (g_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer::ZombieAbortControl");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hZombieAbortControl = EndPrepSDKCall();
	}
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

public bool:OnClientConnect(client, String: rejectmsg[], maxlen)
{
        if (client && !IsFakeClient(client))
        {
		g_bPlayerDisconnected[client] = true;
        }

        return true;
}

public Action:OnClient_TankSpawn(any:client)
{
	g_iTankTotal = GetConVarInt(g_TankTotal);

	new Float:TankSpawnDelay = GetConVarFloat(g_TankSpawnDelay);
	new Float:TankLotteryTime = GetConVarFloat(FindConVar("director_tank_lottery_selection_time"));
	new Float:TankDelay = TankLotteryTime + TankSpawnDelay;

	CreateTimer(TankLotteryTime, Timer_ShowInfectedTankHud, _, TIMER_FLAG_NO_MAPCHANGE);
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
		new flags = GetCommandFlags("z_spawn_old");
		SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);
		FakeClientCommand(FakeClient, "z_spawn_old tank auto")
		SetCommandFlags("z_spawn_old", flags);
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

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

        //new NewTeam = GetEventInt(event, "team");
        new OldTeam = GetEventInt(event, "oldteam");

	if (client == 0 || IsFakeClient(client) || !IsClientInGame(client))
		return;

        if (OldTeam == 3 && Sub_IsPlayerTank(client) && Sub_IsPlayerGhost(client))
	{
		LogMessage("[+] E_PT: Player %N (%d) switched team while a ghosted tank, spawning a tank bot.", client, client);
		CreateTimer(0.5, SpawnExtraTank, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

	if (client == 0 || IsFakeClient(client))
		return;

	if (Sub_IsPlayerTank(client) && Sub_IsPlayerGhost(client))
        {
		if (!g_bPlayerDisconnected[client])
		{
 	               LogMessage("[+] E_PD: Player %N (%d) disconnected while a ghosted tank, spawning a tank bot.", client, client);
        	       CreateTimer(0.5, SpawnExtraTank, client, TIMER_FLAG_NO_MAPCHANGE);
		}
        }

	g_bPlayerDisconnected[client] = true;
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

public Action:Event_VersusMarker(Handle:event, const String:name[], bool:dontBroadcast)
{
	new marker = GetEventInt(event, "marker");

	if (marker > 25)
	{
		if (IsProhibitedMap())
			CreateTimer(float(g_iTankSpawnTime), SpawnExtraTank, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	LogMessage("[+] E_VM: Versus Round (%% completed): %d%", marker);

	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundEnd = true;
        ResetHealthChanged();
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

	if (client == 0 || g_bRoundEnd || !IsClientInGame(client) || !IsValidEntity(client))
		return Plugin_Continue;

	if (Sub_IsPlayerTank(client))
	{
		g_bHealthChanged[client] = true;
		g_bTankInPlay[client] = false;
		g_bFireImmunity[client] = false;
		g_bIsFirstTank = false;
		CreateTimer(3.0, CheckTanks, client);
	}

	return Plugin_Continue;
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

	if (IsFakeClient(client))
	{
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", g_fTankPosition);
		LogMessage("[+] E_TS: Get Tank Vector: %N (%d) (%f)", client, client, g_fTankPosition);
	}

	else
	{
		if (!g_bTankInPlay[client])
		{
			SetEntProp(client, Prop_Send, "m_isCulling", 1, 1);
			SDKCall(g_hZombieAbortControl, client, 0.0);
			SetEntProp(client, Prop_Send, "m_isCulling", 0, 1);
			TeleportEntity(client, g_fTankPosition, NULL_VECTOR, NULL_VECTOR);

			if (!g_bHealthChanged[client])
				SetTankHealth(client);

			g_bTankInPlay[client] = true;
		}
	}
}

public Action:CheckTanks(Handle:timer, Handle:client)
{
	if (g_bRoundEnd)
		return;

	if (CountTanks() <= 0)
	{
		ResetHealthChanged();
	}
}

public CountTanks()
{
	new TanksCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
		{
			if (Sub_IsPlayerTank(i))
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
        if (!IsValidEntity(client) || g_bRoundEnd)
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

		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntityMoveType(client, MOVETYPE_CUSTOM);
		TeleportEntity(client, g_fTankPosition, NULL_VECTOR, NULL_VECTOR);

		LogMessage("[+] STH: (%d/%d/%d) Player %N is a Tank (HP: %d)", _R, _G, _B, client, GetClientHealth(client));
	}

	else
	{
		LogMessage("[+] STH: (%d/%d/%d) The Director has spawned a Tank (HP: %d)", _R, _G, _B, GetClientHealth(client));
	}

	g_bHealthChanged[client] = true;
}

public ResetHealthChanged()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_bHealthChanged[i] = false;
		g_bTankInPlay[i] = false;
		g_bFireImmunity[i] = false;
		g_bPlayerDisconnected[i] = false;
	}

	g_bIsFirstTank = false;
}

public Action:Timer_TeleportTank(Handle:hTimer, any:client)
{
	TeleportEntity(client, g_fTankPosition, NULL_VECTOR, NULL_VECTOR);
}

public Action:Timer_ShowInfectedTankHud(Handle:hTimer, any:client)
{
        if (CountTanks() == 0 || g_bRoundEnd)
        {
                return Plugin_Stop;
        }

        decl String:_sBuffer [150];
        new Handle:_hInfectedTankHud;

        _hInfectedTankHud = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
        SetPanelTitle(_hInfectedTankHud, "Infected Tanks:");
        DrawPanelText(_hInfectedTankHud, " ");

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsValidEntity(i) && IsClientInGame(i) && GetClientTeam(i) == 3)
                {
			if (IsPlayerAlive(i) && Sub_IsPlayerTank(i) && !Sub_IsPlayerGhost(i))
                        {
				if (!IsFakeClient(i))
	                                Format(_sBuffer, sizeof(_sBuffer), "%N. (HP: %i)", i, GetClientHealth(i));
				else
					Format(_sBuffer, sizeof(_sBuffer), "Tank. (HP: %i)", GetClientHealth(i));

                                DrawPanelItem(_hInfectedTankHud, _sBuffer);
                        }
                }
        }

        for (new i = 1; i <= MaxClients; i++)
        {
                if (IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))
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
	CreateTimer(1.0, Timer_ShowInfectedTankHud, _, TIMER_FLAG_NO_MAPCHANGE)
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

public Sub_IsPlayerGhost(any:Client)
{
        if (IsValidEntity(Client) && GetEntProp(Client, Prop_Send, "m_isGhost"))
                return true;
        else
                return false;
}

public Sub_IsPlayerTank(any:Client)
{
	if (IsValidEntity(Client) && GetEntProp(Client, Prop_Send, "m_zombieClass") == 8)
                return true;
        else
                return false;
}

public bool:IsProhibitedMap()
{
        new String:map[128];
        GetCurrentMap(map, sizeof(map));

        if (StrContains(map, "c1m1_hotel") != -1)
        {
                g_iTankSpawnTime = GetRandomInt(90,120);
                return true;
        }

        if (StrContains(map, "c4m4_milltown") != -1)
        {
                g_iTankSpawnTime = GetRandomInt(60,120);
                return true;
        }

        if (StrContains(map, "c5m1_waterfront") != -1)
        {
                g_iTankSpawnTime = GetRandomInt(60,80);
                return true;
        }

        return false;
}

/*public Action:Timer_PauseTank(Handle:hTimer, any:client)
{
        if (!IsValidEntity(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
	{
		return;
	}

	//LogMessage("[+] PT: Pausing+Ghosting Tank (%N, %d)", client, client);
        SetEntityMoveType(client, MOVETYPE_NONE);
        SetEntProp(client, Prop_Send, "m_isGhost", 1, 1);
}

public Action:Timer_ResumeTank(Handle:hTimer, any:client)
{
        if (!IsClientInGame(client) || !IsValidEntity(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
	{
		return;
	}

	//LogMessage("[+] PT: Resuming Tank (%N, %d)", client, client);
        SetEntityMoveType(client, MOVETYPE_CUSTOM);
        //SetEntProp(client, Prop_Send, "m_isGhost", 0, 1);
}
*/
