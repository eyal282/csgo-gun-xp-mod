#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

native int GunXP_UnlockShop_RegisterProduct(char sName[64], char sDescription[512], int cost, int minLevel, char[] sClassname, int gamemode);
native bool GunXP_UnlockShop_IsProductUnlocked(int client, int productIndex);

int teleportGrenadeIndex = -1;

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "GunXP_UnlockShop"))
	{
		RegisterProduct();
	}
}

public void OnConfigsExecuted()
{
    RegisterProduct();

}
public void OnPluginStart()
{
    RegisterProduct();

    HookEvent("smokegrenade_detonate", Event_SmokegrenadeDetonate, EventHookMode_Post);
}

public void RegisterProduct()
{
    teleportGrenadeIndex = GunXP_UnlockShop_RegisterProduct("Teleport Grenade", "Spawn with a Smoke Grenade\nYou will teleport to the smoke grenade after it detonates.\nTeleportation will not occur if you would either\nget stuck or teleport to another teleport entity",200, 7, "weapon_smokegrenade", 1);
}

public void GunXP_OnPlayerSpawned(int client)
{

    if(GunXP_UnlockShop_IsProductUnlocked(client, teleportGrenadeIndex))
    {
          GivePlayerItem(client, "weapon_smokegrenade");
    }
}

public Action Event_SmokegrenadeDetonate(Handle hEvent, const char[] sName, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    if(client == 0)
        return;

    else if(!IsPlayerAlive(client))
        return;

    if(GunXP_UnlockShop_IsProductUnlocked(client, teleportGrenadeIndex))
    {
        float fOrigin[3];

        fOrigin[0] = GetEventFloat(hEvent, "x");
        fOrigin[1] = GetEventFloat(hEvent, "y");
        fOrigin[2] = GetEventFloat(hEvent, "z");

        if(!IsPlayerStuck(client, fOrigin))
        {
            TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);

            return;
        }

        fOrigin[2] += 32.0;

        if(!IsPlayerStuck(client, fOrigin))
        {
            TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);

            TeleportToGround(client);

            return;
        }

        PrintToChat(client, "Could not teleport without getting stuck...");
    }
}

public void GunXP_UnlockShop_OnProductBuy(int client, int productIndex)
{
    if(productIndex == teleportGrenadeIndex && IsPlayerAlive(client))
    {
        GivePlayerItem(client, "weapon_smokegrenade");
    }
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


public void OnEntityCreated(int entity, const char[] classname)
{
		
	if(StrEqual(classname, "smokegrenade_projectile"))
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);

}

public void OnSpawnPost(int entity)
{
    SDKHook(entity, SDKHook_Touch, _SDKHook_Touch);
}

public void _SDKHook_Touch(int smoke, int toucher)
{
    char sClassname[64];
    GetEdictClassname(toucher, sClassname, sizeof(sClassname));

    if(StrEqual(sClassname, "trigger_teleport"))
    {
        int flags = GetEntProp(toucher, Prop_Send, "m_spawnflags");

        if(flags & (1<<0))
        {
            int owner = GetEntPropEnt(smoke, Prop_Send, "m_hOwnerEntity");

            if(owner == -1)
                return;

            else if(!GunXP_UnlockShop_IsProductUnlocked(owner, teleportGrenadeIndex))
                return;

            AcceptEntityInput(smoke, "Kill");
            PrintToChat(owner, "Teleport failed! Cannot teleport to a teleport");
        }
    }
}

public void _SDKHook_StartTouch(int smoke, int toucher)
{
    char sClassname[64];
    GetEdictClassname(toucher, sClassname, sizeof(sClassname));

    PrintToChatAll("b %s", sClassname);
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