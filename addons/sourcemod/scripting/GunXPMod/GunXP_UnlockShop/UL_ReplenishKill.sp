#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

// sClassname = classname of weapon required to use this product. Only affects min level.
native void GunXP_UnlockShop_ReplenishProducts(int client, bool bOnlyUL);

native int GunXP_UnlockShop_RegisterProduct(char sName[64], char sDescription[512], int cost, int minLevel, char[] sClassname);
native bool GunXP_UnlockShop_IsProductUnlocked(int client, int productIndex);

int replenishIndex = -1;

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

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void RegisterProduct()
{
    replenishIndex = GunXP_UnlockShop_RegisterProduct("Replenish Everything On Kill", "Whenever you make a kill, you will get every unlock shop product as if you spawned.\nIf Zeus is enabled, you will also gain a new Zeus\nDoes not apply for skills.", 400, 0, "");
}

public Action Event_PlayerDeath(Handle hEvent, const char[] sName, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    if(attacker == 0)
        return;

    else if(!IsPlayerAlive(attacker))
        return;

    if(GunXP_UnlockShop_IsProductUnlocked(attacker, replenishIndex))
    {
       GunXP_UnlockShop_ReplenishProducts(attacker, false);
    }
}