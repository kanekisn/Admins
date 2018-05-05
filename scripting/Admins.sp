#include <sourcemod>
#include <materialadmin>

int iLike[MAXPLAYERS+1], iDis[MAXPLAYERS+1], iActives[MAXPLAYERS+1];

//kv
int kGroup, kImm, kTime, kActives_Count;

char g_sSteamID[MAXPLAYERS+1][32];
char sFlag[8];
char g_iTarget[16], g_sTargetName[64];

Database g_hDatabase = null;

public void OnPluginStart()
{
	Database.Connect(DatabaseCallback, "admins");
	
	RegConsoleCmd("sm_admins", AdminsCMD_Callback)
}

public void OnConfigsExecuted()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/adm/admins_list.ini");
	KeyValues kv = new KeyValues("Admlist");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey()) SetFailState("[Admlist] file is not found (%s)", sPath);
	
	kv.Rewind();
	
	if(kv.JumpToKey("Settings"))
	{
		kGroup = kv.GetNum("GroupEnable", 1);
		kImm   = kv.GetNum("ImmEnable",   1);
		kTime  = kv.GetNum("TimeEnable",  1);
		kActives_Count  = kv.GetNum("Count",  3);
		kv.GetString("Flag", sFlag, sizeof(sFlag));
	}
	else
	{
		SetFailState("[Admlist] section Settings is not found (%s)", sPath);
	}
		
	delete kv;
}

public void DatabaseCallback(Database hDB, const char[] sError, any data)
{
	if(!hDB) 
	{
		char sSQLError[215];
		hDB = SQLite_UseDatabase("admins_info", sSQLError, sizeof(sSQLError));
		if(!hDB)
		{
			LogError("[Admins] - MYSQL Could not connect to the database (%s)", sError);
			LogError("[Admins] - SQL Could not connect to the database (%s)", sSQLError);
			return;
		}
	}
	
	char sIdent[16];
	
	g_hDatabase = hDB;
	g_hDatabase.SetCharset("utf8");
	
	DBDriver hDatabaseDriver = g_hDatabase.Driver;
	hDatabaseDriver.GetIdentifier(sIdent, sizeof(sIdent));
	
	switch(sIdent[0])
	{
		case's':
		{
			g_hDatabase.Query(DBConnect_Callback, "CREATE TABLE IF NOT EXISTS `adm_users` (\
											   `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
											   `auth` VARCHAR(32) NOT NULL,\
											   `actives` INTEGER NOT NULL default '0');");
											   
			g_hDatabase.Query(DBConnect_Callback, "CREATE TABLE IF NOT EXISTS `adm_admins` (\
											   `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
											   `auth` VARCHAR(32) NOT NULL,\
											   `likes` INTEGER NOT NULL,\
											   `dislikes` INTEGER NOT NULL);");								   
		}
		case'm':
		{		
			g_hDatabase.Query(DBConnect_Callback, "CREATE TABLE IF NOT EXISTS `adm_users` (\
											   `id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,\
											   `auth` VARCHAR(32) NOT NULL,\
											   `actives` INTEGER NOT NULL default '0');");
											   
			g_hDatabase.Query(DBConnect_Callback, "CREATE TABLE IF NOT EXISTS `adm_admins` (\
											   `id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,\
											   `auth` VARCHAR(32) NOT NULL,\
											   `likes` INTEGER NOT NULL default '0',\
											   `dislikes` INTEGER NOT NULL default '0');");
		}
	}
}

public void DBConnect_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] Could not create tables: %s", szError);
		return;
	}
}

public void OnClientPutInServer(int iClient)
{
	if(!IsFakeClient(iClient) && IsClientAuthorized(iClient))
	{
		char szQuery[128];
		GetClientAuthId(iClient, AuthId_Engine, g_sSteamID[iClient], sizeof(g_sSteamID));
		FormatEx(szQuery, sizeof(szQuery), "SELECT `id` FROM `adm_users` WHERE `auth` = '%s';", g_sSteamID[iClient]);
		
		g_hDatabase.Query(DB_GetAuthCallback, szQuery, GetClientUserId(iClient));
	}
}

public void DB_GetAuthCallback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] DB_GetAuthCallback: %s", szError);
		return;
	}
	
	int iClient = GetClientOfUserId(data);
	
	if(!iClient) return;
	
	if(!hResults.FetchRow())
	{
		char szQuery[128];
		
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `adm_users` (`auth`, `actives`) VALUES ('%s', %i);", g_sSteamID[iClient], kActives_Count);
		g_hDatabase.Query(InsetUser_CallBack, szQuery); 
	}
}

public void InsetUser_CallBack(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] InsetUser_CallBack: %s", szError);
		return;
	}
}

void GetAdminRep(int iClient)
{
	char szQuery[128];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `likes`, `dislikes` FROM `adm_admins` WHERE `auth` = '%s';", g_sSteamID[iClient]);
	g_hDatabase.Query(GetAdminRep_Callback, szQuery, GetClientUserId(iClient), DBPrio_High);
}

public void GetAdminRep_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] GetAdminRep_Callback: %s", szError);
		return;
	}
	
	int iClient = GetClientOfUserId(data);
	
	if(!iClient) return;
	
	if(hResults.FetchRow())
	{
		iLike[iClient] = hResults.FetchInt(0);
		iDis[iClient] = hResults.FetchInt(1);
	}
}

void GetPlayerActives(iClient)
{
	char szQuery[128];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `actives` FROM `adm_users` WHERE `auth` = '%s';", g_sSteamID[iClient]);
	g_hDatabase.Query(GetPlayerActives_Callback, szQuery, GetClientUserId(iClient));
}

public void GetPlayerActives_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] GetPlayerActives_Callback: %s", szError);
		return;
	}
	
	int iClient = GetClientOfUserId(data);
	
	if(!iClient) return;
	
	if(hResults.FetchRow())
	{
		iActives[iClient] = hResults.FetchInt(0);
	}
}

void iActiveDel(int iClient)
{
	char szQuery[128];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `adm_users` SET 'actives' = `actives` - 1 WHERE `auth` = '%s';", g_sSteamID[iClient]);
	g_hDatabase.Query(iActiveDel_Callback, szQuery);
}

public void iActiveDel_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] iActiveDel: %s", szError);
		return;
	}
}


bool CheckAdminFlags(int iClient, int iFlag)
{
	int iUserFlags = GetUserFlagBits(iClient);
	if (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag)
		return true;
	else
		return false;
}

public Action AdminsCMD_Callback(int iClient, int iArgs)
{
	Menu hMenu = new Menu(CMD_MenuHandler);
	
	hMenu.SetTitle("Список онлайн Администраторов\n \n");
	
	int iCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && CheckAdminFlags(i, ReadFlagString(sFlag)))
		{
			IntToString(GetClientUserId(i), g_iTarget, sizeof(g_iTarget));
			GetClientName(i, g_sTargetName, sizeof(g_sTargetName));
			hMenu.AddItem(g_iTarget, g_sTargetName);
			
			GetAdminRep(i);
			
			iCount++;
		}
	}
	
	GetPlayerActives(iClient);
	
	if(!iCount) PrintToChat(iClient, "\x03Админов нету!");
	
	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int CMD_MenuHandler(Menu hMenu, MenuAction action, int iClient, int iItem)
{    
	switch(action)
	{
		case MenuAction_End:    
		{
			delete hMenu;
		}
		case MenuAction_Select:
		{
			hMenu.GetItem(iItem, g_iTarget, 16);
			
			int iUser = StringToInt(g_iTarget);
			int iTarg = GetClientOfUserId(iUser);
			
			if(IsClientInGame(iTarg))
			{
				MenuInfo(iClient, iTarg);
			}
		}
	}
}

void MenuInfo(int iClient, int iTarg)
{
	Menu hMenu = new Menu(MenuInfo_Handler);
	
	char sGroup[64], sTime[64], sBuffer[512];
	
	AdminId	aid = GetUserAdmin(iTarg);
	int iGcount = GetAdminGroupCount(aid);
	int iTime = MAGetAdminExpire(aid);
	
	if (iTime == 0)
		strcopy(sTime, 64, "Навсегда");
	else
		FormatTime(sTime, 64, "%x", iTime);
	
	hMenu.SetTitle("Администратор - %N\n \n", iTarg);
	
	if(kGroup)
	{     
		for (int i = 0; i < iGcount; i++)
		{
			GroupId gid = GetAdminGroup(aid, i, sGroup, sizeof(sGroup));
			FormatEx(sBuffer, sizeof(sBuffer), "Группа: %s | ID: %d", sGroup, gid);
			hMenu.AddItem("0", sBuffer, ITEMDRAW_DISABLED);
		}
	}
	
	if(kImm){
	int iImmunity = GetAdminImmunityLevel(GetUserAdmin(iTarg));
	FormatEx(sBuffer, sizeof(sBuffer), "Иммунитет: %i", iImmunity);
	hMenu.AddItem("1", sBuffer, ITEMDRAW_DISABLED);
	}
	
	if(kTime){
		FormatEx(sBuffer,   sizeof(sBuffer),    "Истекает: %s", sTime);
		hMenu.AddItem("3",  sBuffer,    ITEMDRAW_DISABLED);
	}
	
	FormatEx(sBuffer,   sizeof(sBuffer),    "Репутация [+ %i/ - %i]", iLike[iTarg], iDis[iTarg]);
	hMenu.AddItem("4",  sBuffer,    ITEMDRAW_DISABLED);
	
	FormatEx(sBuffer,   sizeof(sBuffer),    "Поставить Лайк");
	hMenu.AddItem("5",  sBuffer);
	
	FormatEx(sBuffer,   sizeof(sBuffer),    "Поставить Дизлайк");
	hMenu.AddItem("6",  sBuffer);
	
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public int MenuInfo_Handler(Menu hMenu, MenuAction action, int iClient, int iItem)
{   
	switch(action)
	{
		case MenuAction_End:    
		{
			delete hMenu;
		}
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				AdminsCMD_Callback(iClient, 0);
			}
		}
		case MenuAction_Select:
		{
			char szInfo[7];
			
			int iUser = StringToInt(g_iTarget);
			int iTarg = GetClientOfUserId(iUser);
			
			if(!iActives[iClient]){
				PrintToChat(iClient, "\x03Вы исчерпали кол-во голосов!");
				return;
			}

			if(iClient == iTarg){
				PrintToChat(iClient, "\x03Себе ставить запрещено!");
				return;
			}
			
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			
			switch(szInfo[0])
			{
				case'5':
				{
					char szQuery[128];
					FormatEx(szQuery, sizeof(szQuery), "SELECT `id` FROM `adm_admins` WHERE `auth` = '%s';", g_sSteamID[iTarg]);
					g_hDatabase.Query(SetRepLike_Callback, szQuery, GetClientUserId(iTarg));
					PrintToChat(iClient, "Лайк поставлен!");
					iActiveDel(iClient);
				}
				case'6':
				{
					char szQuery[128];
					FormatEx(szQuery, sizeof(szQuery), "SELECT `id` FROM `adm_admins` WHERE `auth` = '%s';", g_sSteamID[iTarg]);
					g_hDatabase.Query(SetRepDis_Callback, szQuery, GetClientUserId(iTarg));
					PrintToChat(iClient, "Дизлайк поставлен!");
					iActiveDel(iClient);
				}
			}
		}
	}
}

public void SetRepLike_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] SetRepLike_Callback: %s", szError);
		return;
	}
	
	char szQuery[128];
	
	int iClient = GetClientOfUserId(data);
	
	if(!iClient) return;
	
	if(!hResults.FetchRow())
	{
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `adm_admins` (`auth`, `likes`, `dislikes`) VALUES ('%s', 1, 0);", g_sSteamID[iClient]);
		g_hDatabase.Query(SetRepLike_Callback, szQuery);
	}
	else
	{
		FormatEx(szQuery, sizeof(szQuery), "UPDATE `adm_admins` SET `likes` = `likes` + 1 WHERE `auth` = '%s';", g_sSteamID[iClient]);
		g_hDatabase.Query(SetRepLike_Callback, szQuery);
	}
}

public void SetRepDis_Callback(Database hDatabase, DBResultSet hResults, const char[] szError, any data)
{
	if(szError[0])
	{
		LogError("[Admins] SetRepDis_Callback: %s", szError);
		return;
	}
	
	char szQuery[128];
	
	int iClient = GetClientOfUserId(data);
	
	if(!iClient) return;
	
	if(!hResults.FetchRow())
	{
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `adm_admins` (`auth`, `likes`, `dislikes`) VALUES ('%s', 0, 1);", g_sSteamID[iClient]);
		g_hDatabase.Query(SetRepDis_Callback, szQuery);
	}
	else
	{
		FormatEx(szQuery, sizeof(szQuery), "UPDATE `adm_admins` SET `dislikes` = `dislikes` + 1 WHERE `auth` = '%s';", g_sSteamID[iClient]);
		g_hDatabase.Query(SetRepDis_Callback, szQuery);
	}
}

	
	