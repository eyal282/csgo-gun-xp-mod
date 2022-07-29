#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

native int GunXP_UnlockShop_RegisterProduct(char sName[64], char sDescription[512], int cost, int minLevel, char[] sClassname);
native bool GunXP_UnlockShop_IsProductUnlocked(int client, int productIndex);

int seekingGrenadeIndex = -1;


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
}

public void RegisterProduct()
{
	seekingGrenadeIndex = GunXP_UnlockShop_RegisterProduct("Seeking HE Grenade", "Spawn with an HE Grenade\nHE Grenade seeks players in range.", 150, 0, "weapon_hegrenade");
}
public Action Event_PlayerSpawn(Handle hEvent, const char[] sName, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    if(client == 0)
        return;

    else if(!IsPlayerAlive(client))
        return;

    if(GunXP_UnlockShop_IsProductUnlocked(client, seekingGrenadeIndex))
    {
        CreateTimer(0.5, Timer_GiveGrenade, GetClientUserId(client));
    }
}

public Action Timer_GiveGrenade(Handle hTimer, int UserId)
{
    int client = GetClientOfUserId(UserId);

    if(client == 0)
        return;

    else if(!IsPlayerAlive(client))
        return;

    GivePlayerItem(client, "weapon_hegrenade");
}

public void GunXP_UnlockShop_OnProductBuy(int client, int productIndex)
{
    if(productIndex == seekingGrenadeIndex && IsPlayerAlive(client))
    {
        GivePlayerItem(client, "weapon_hegrenade");
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
		
	if(StrEqual(classname, "hegrenade_projectile"))
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

            else if(!GunXP_UnlockShop_IsProductUnlocked(owner, seekingGrenadeIndex))
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