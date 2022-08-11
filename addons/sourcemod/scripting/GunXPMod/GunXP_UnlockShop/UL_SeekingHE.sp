#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

#define MIN_FLOAT -2147483647.0

native bool GunXP_IsFFA();
native int GunXP_UnlockShop_RegisterProduct(char sName[64], char sDescription[512], int cost, int minLevel, char[] sClassname, int gamemode);
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
	seekingGrenadeIndex = GunXP_UnlockShop_RegisterProduct("Seeking HE Grenade", "Spawn with an HE Grenade\nHE Grenade seeks players in range.", 0, 0, "weapon_hegrenade", 1);
}

public void GunXP_OnPlayerSpawned(int client)
{
    if(GunXP_UnlockShop_IsProductUnlocked(client, seekingGrenadeIndex))
    {   
		GivePlayerItem(client, "weapon_hegrenade");
    }
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
    SDKHook(entity, SDKHook_ThinkPost, SDKEvent_OnGrenadeThink);
}

public void SDKEvent_OnGrenadeThink(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if(owner == -1)
		return;

	int winner;
	float fWinnerDistance;

	float fNadeOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fNadeOrigin);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(i == owner)
			continue;

		else if(GetClientTeam(i) == GetClientTeam(owner) && !GunXP_IsFFA())
			continue;

		float fOrigin[3];
		GetClientEyePosition(i, fOrigin);

		float dist = GetVectorDistance(fOrigin, fNadeOrigin);

		if(dist > 600.0)
			continue;

		if (winner == 0)
		{
			winner = i;
			fWinnerDistance = dist;
		}

		else if (fWinnerDistance > dist)
		{
			winner = i;
			fWinnerDistance = dist;
		}
	}

	if (winner != 0)
	{
		if(fWinnerDistance > 3.0)
			FollowTargetPlayer(entity, winner, 500.0);
		
		else
		{
			AcceptEntityInput(entity, "SetParent", winner, entity);
			SDKUnhook(entity, SDKHook_ThinkPost, SDKEvent_OnGrenadeThink);
		}
	}
}

stock void FollowTargetPlayer(int entity, int target, float speed) 
{
	float fOrigin[3], fTargetOrigin[3];

	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);
	GetClientEyePosition(target, fTargetOrigin);

	float fDiff[3];
	fDiff[0] = fTargetOrigin[0] - fOrigin[0];
	fDiff[1] = fTargetOrigin[1] - fOrigin[1];
	fDiff[2] = fTargetOrigin[2] - fOrigin[2];

	float length = GetVectorLength(fDiff);

	float fVelocity[3];
	fVelocity[0] = fDiff[0] * (speed / length);
	fVelocity[1] = fDiff[1] * (speed / length);
	fVelocity[2] = fDiff[2] * (speed / length);

	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, fVelocity);
}