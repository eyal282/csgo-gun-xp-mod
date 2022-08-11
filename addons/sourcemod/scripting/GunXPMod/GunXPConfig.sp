#include <sourcemod>
#include <sdktools>
#include <eyal-jailbreak>
#include <autoexecconfig>

#define semicolon 1
#define newdecls  required

public Plugin myinfo =
{
	name        = "GunXP Config",
	author      = "Eyal282",
	description = "Basic Gun XP Config",
	version     = "1.0",
	url         = ""
};

enum struct enCvarList
{
	char name[64];
	char value[256];
}

// Cvar, Value
enCvarList cvarList[] = {
	{"mp_death_drop_breachcharge",          "0"         },
	{ "mp_death_drop_defuser",         "0"         },
	{ "mp_death_drop_grenade",           "0"         },
	{ "mp_death_drop_gun",         "0"         },
	{ "mp_death_drop_healthshot",       "0"         },
	{ "mp_death_drop_taser",     "0"         },

	{ "sv_full_alltalk",       "1"         },
	{ "sv_alltalk",            "1"         },

	{ "mp_ignore_round_win_conditions", "0" },
	// Gun XP deals with secondary ammo. We can't afford to allow infinite grenades...

	{ "mp_respawn_immunitytime", "1000000000"},
	{ "sv_infinite_ammo",		"0" },

    // If you copied surf combat into Gun XP...
    { "mp_items_prohibited", "" },

 // These two remove the money hud.
	{ "mp_playercashawards",   "0"         },
	{ "mp_teamcashawards",     "0"         }
};

Handle hcv_mpRoundTime;
Handle hcv_RoundTime;

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig_SetFile("GunXPConfig");

	hcv_RoundTime = UC_CreateConVar("gun_xp_roundtime", "15", "mp_roundtime, but doesn't work for auto respawn mode.");

	AutoExecConfig_ExecuteFile();

	hcv_mpRoundTime = FindConVar("mp_roundtime");

	AutoExecConfig_CleanFile();
}

public Action Event_RoundStart(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	if(GameRules_GetProp("m_bWarmupPeriod"))
	{
		ServerCommand("mp_warmup_end");
	}
}
public void OnMapStart()
{
	for(float i=0.0;i < 5.0;i += 0.2)
	{
		CreateTimer(i, Timer_ExecuteConfig, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ExecuteConfig(Handle hTimer)
{
	for (int i = 0; i < sizeof(cvarList); i++)
	{
		ConVar convar = FindConVar(cvarList[i].name);
		if (convar != null)
		{
			SetConVarString(convar, cvarList[i].value);
		}
	}

	SetConVarInt(hcv_mpRoundTime, GetConVarInt(hcv_RoundTime));
}
