#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

Handle hTimer_Spawn[MAXPLAYERS+1];

// Make identifier as descriptive as possible.
native int GunXP_SkillShop_RegisterSkill(char identifier[32], char name[64], char description[512], int cost, int gamemode);
native bool GunXP_SkillShop_IsSkillUnlocked(int client, int skillIndex);

int vampireIndex = -1;

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "GunXP_UnlockShop"))
	{
		RegisterSkill();
	}
}

public void OnConfigsExecuted()
{
    RegisterSkill();

}
public void OnPluginStart()
{
    RegisterSkill();

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    for (int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i))
            continue;
            
        OnClientPutInServer(i);
    }
}

public void RegisterSkill()
{
    vampireIndex = GunXP_SkillShop_RegisterSkill("VampireAndHP", "Vampire", "30% HP regen when you deal damage.\n+30 HP on spawn", 1, 1);
}

public void OnClientDisconnect(int client)
{
	if(hTimer_Spawn[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_Spawn[client]);
		hTimer_Spawn[client] = INVALID_HANDLE;
	}
}
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, Event_TakeDamageAlivePost);
}

public void Event_TakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if(!IsPlayer(attacker))
        return;

    else if(!IsPlayerAlive(attacker))
        return;

    else if(!GunXP_SkillShop_IsSkillUnlocked(attacker, vampireIndex))
        return;
    
    else if(damage < 1.0)
        return;

    int HPToGive = RoundToCeil(damage * 0.3);

    if(HPToGive + GetEntityHealth(attacker) >= GetEntityMaxHealth(attacker))
        SetEntityHealth(attacker, GetEntityMaxHealth(attacker));

    else
        SetEntityHealth(attacker, GetEntityHealth(attacker) + HPToGive);
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] sName, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    if(client == 0)
        return;

    else if(!IsPlayerAlive(client))
        return;

    SetEntityMaxHealth(client, 100);
    
    if(GunXP_SkillShop_IsSkillUnlocked(client, vampireIndex))
    {
        hTimer_Spawn[client] = CreateTimer(0.5, Timer_GiveHealth, client, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_GiveHealth(Handle hTimer, int client)
{
	hTimer_Spawn[client] = INVALID_HANDLE;

	if(!IsPlayerAlive(client))
		return;

    SetEntityHealth(client, GetEntityHealth(client) + 30);
    SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 30);
}


stock bool IsPlayer(int client)
{
	if(client == 0)
		return false;
	
	else if(client > MaxClients)
		return false;
	
	return true;
}


public void BitchSlapBackwards(int victim, int attacker, float strength)    // Stole the dodgeball tactic from https://forums.alliedmods.net/showthread.php?t=17116
{
	float origin[3], velocity[3];
	GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", origin);
	GetVelocityFromOrigin(victim, origin, strength, velocity);
	velocity[2] = strength / 10.0;

	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
}
stock void GetVelocityFromOrigin(int ent, float fOrigin[3], float fSpeed, float fVelocity[3])    // Will crash server if fSpeed = -1.0
{
	float fEntOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fEntOrigin);

	// Velocity = Distance / Time

	float fDistance[3];
	fDistance[0] = fEntOrigin[0] - fOrigin[0];
	fDistance[1] = fEntOrigin[1] - fOrigin[1];
	fDistance[2] = fEntOrigin[2] - fOrigin[2];

	float fTime = (GetVectorDistance(fEntOrigin, fOrigin) / fSpeed);

	if (fTime == 0.0)
		fTime = 1 / (fSpeed + 1.0);

	fVelocity[0] = fDistance[0] / fTime;
	fVelocity[1] = fDistance[1] / fTime;
	fVelocity[2] = fDistance[2] / fTime;
}

stock bool IsPlayerStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
	float vecMin[3], vecMax[3], vecOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	if (UC_IsNullVector(Origin))
	{
		GetClientAbsOrigin(client, vecOrigin);

		vecOrigin[2] += HeightOffset;
	}
	else
	{
		vecOrigin = Origin;

		vecOrigin[2] += HeightOffset;
	}

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);
	return TR_DidHit();
}

stock void TeleportToGround(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3], vecFakeOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	GetClientAbsOrigin(client, vecOrigin);
	vecFakeOrigin = vecOrigin;

	vecFakeOrigin[2] = MIN_FLOAT;

	TR_TraceHullFilter(vecOrigin, vecFakeOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);

	TR_GetEndPosition(vecOrigin);

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

stock bool UC_IsNullVector(const float Vector[3])
{
	return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}

public bool TraceRayDontHitPlayers(int entityhit, int mask)
{
	return (entityhit > MaxClients || entityhit == 0);
}

stock void SetEntityMaxHealth(int entity, int amount)
{
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", amount);
}

stock int GetEntityMaxHealth(int entity)
{
	return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

stock int GetEntityHealth(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}