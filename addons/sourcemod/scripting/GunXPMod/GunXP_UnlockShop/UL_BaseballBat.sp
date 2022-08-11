#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <fpvm_interface>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

// sClassname = classname of weapon required to use this product. Only affects min level.
native int GunXP_UnlockShop_RegisterProduct(char sName[64], char sDescription[512], int cost, int minLevel, char[] sClassname, int gamemode);
native bool GunXP_UnlockShop_IsProductUnlocked(int client, int productIndex);

int baseballBatIndex = -1;

int vmBaseball;
int wmBaseball;

public void OnMapStart()
{
	vmBaseball = PrecacheModel("models/weapons/eminem/adidas_baseball_bat/v_adidas_baseball_bat.mdl");
	wmBaseball = PrecacheModel("models/weapons/eminem/adidas_baseball_bat/w_adidas_baseball_bat.mdl");

	AddFolderToDownloadsTable("models/weapons/eminem/adidas_baseball_bat");
}

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

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
	}
}

public void RegisterProduct()
{
    baseballBatIndex = GunXP_UnlockShop_RegisterProduct("Baseball Bat", "Sends players flying\nDeals 300 damage on backstabs and right click\nDeals 90 damage on left clicks", 90, 0, "weapon_knife", 3);
}

public void GunXP_OnPlayerSpawned(int client)
{
    if(GunXP_UnlockShop_IsProductUnlocked(client, baseballBatIndex))
    {
        FPVMI_AddViewModelToClient(client, "weapon_knife", vmBaseball);
        FPVMI_AddWorldModelToClient(client, "weapon_knife", wmBaseball);
    }
    else
    {
        if(FPVMI_GetClientViewModel(client, "weapon_knife") == vmBaseball)
            FPVMI_RemoveViewModelToClient(client, "weapon_knife");

        if(FPVMI_GetClientWorldModel(client, "weapon_knife") == wmBaseball)
            FPVMI_RemoveWorldModelToClient(client, "weapon_knife");
    }
}


public void GunXP_UnlockShop_OnProductBuy(int client, int productIndex)
{
    if(productIndex == baseballBatIndex)
    {
        FPVMI_AddViewModelToClient(client, "weapon_knife", vmBaseball);
        FPVMI_AddWorldModelToClient(client, "weapon_knife", wmBaseball);
    }
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKEvent_OnTakeDamage);
}

public Action SDKEvent_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if(!IsPlayer(attacker))
           return Plugin_Continue;

    int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

    if(weapon == -1)
        return Plugin_Continue;

    char sClassname[64];
    GetEdictClassname(weapon, sClassname, sizeof(sClassname));

    if(strncmp(sClassname, "weapon_knife", 12) != 0)
        return Plugin_Continue;

    else if(!GunXP_UnlockShop_IsProductUnlocked(attacker, baseballBatIndex))
        return Plugin_Continue;

    if(damage >= 55)
        damage = 300.0;

    else
        damage = 90.0;

    BitchSlapBackwards(victim, attacker, 5150.0);

    return Plugin_Changed;
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


//-----STOCKS-----//


char ValidFormats[][] = //VALID, DOWNLOADABLE FILE FORMATS
{
	"mdl", "phy", "vtx", "vvd", //Model files
	"vmt", "vtf", "png", "svg", //Texture and material files
	"mp3", "wav", "pcf" //Sound files
};

void AddFolderToDownloadsTable(char[] Folder)
{
	if(DirExists(Folder))
	{
		Handle DIR = OpenDirectory(Folder);
		char BUFFER[PLATFORM_MAX_PATH];
		FileType FILETYPE = FileType_Unknown;
		
		while(ReadDirEntry(DIR, BUFFER, sizeof(BUFFER), FILETYPE))
		{
			if(!StrEqual(BUFFER, "") && !StrEqual(BUFFER, ".") && !StrEqual(BUFFER, ".."))
			{
				Format(BUFFER, sizeof(BUFFER), "%s/%s", Folder, BUFFER);
				if(FILETYPE == FileType_File)
				{
					if(FileExists(BUFFER, true) && IsFileDownloadable(BUFFER))
					{
						AddFileToDownloadsTable(BUFFER);
					}
				}
				else if(FILETYPE == FileType_Directory)
				{
					AddFolderToDownloadsTable(BUFFER);
				}
			}
		}
		CloseHandle(DIR);
	}
	else
	{
		LogError("Automatic Downloader: Directory not exists - \"%s\"", Folder);
	}
}


bool IsFileDownloadable(char[] string)
{
	char buffer[PLATFORM_MAX_PATH];
	GetFileExtension(string, buffer, sizeof(buffer));
    
	for(int i = 0; i < sizeof(ValidFormats); i++)
	{
		if(StrEqual(buffer, ValidFormats[i], false))
		{
			return true;
		}
	}
	return false;
}

bool GetFileExtension(const char[] filepath, char[] filetype, int filetypelen)
{
    int loc = FindCharInString(filepath, '.', true);
    if(loc == -1)
    {
        filetype[0] = '\0';
        return false;
    }
    strcopy(filetype, filetypelen, filepath[loc + 1]);
    return true;
}