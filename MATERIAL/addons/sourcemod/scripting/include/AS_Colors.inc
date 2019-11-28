int		g_iColorsOther[] = {0xFFFFFF, 0xFF0000, 0x00AD00, 0x00FF00, 0x99FF99, 0xFF4040, 0xCCCCCC, 0xFFBD6B, 0xFA8B00, 0x99CCFF, 0x3D46FF, 0xFA00FA};
char		g_sColors[][] = {"{WHITE}", "{RED}", "{GREEN}", "{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", "{PURPLE}"};
char		g_sColorsCSGO[][] = {"\x01", "\x02", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E"};


stock void A_PrintToChat(int iClient, char[] szMessage, any ...)
{
	if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		char szBuffer[PLATFORM_MAX_PATH], szNewMessage[PLATFORM_MAX_PATH];

		switch(GetEngineVersion())
		{
			case Engine_CSGO:
			{
				Format(szBuffer, sizeof(szBuffer), " \x01%s", szMessage);
				VFormat(szNewMessage, sizeof(szNewMessage), szBuffer, 3);

				for(int i = 0; i < 12; i++)
				{
					ReplaceString(szNewMessage, sizeof(szNewMessage), g_sColors[i], g_sColorsCSGO[i]);
				}
				ReplaceString(szNewMessage, sizeof(szNewMessage), "{TEAM}", "\x03");
			}

			case Engine_CSS:
			{
				char sBuff[64];
				Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
				VFormat(szNewMessage, sizeof(szNewMessage), szBuffer, 3);

				switch(GetClientTeam(iClient))
				{
					case 1: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[6]);
					case 2: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[5]);
					case 3: Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[9]);
				}
				ReplaceString(szNewMessage, sizeof(szNewMessage), "{TEAM}", sBuff);

				for(int i = 0; i < 12; i++)
				{
					Format(sBuff, sizeof(sBuff), "\x07%06X", g_iColorsOther[i]);
					ReplaceString(szNewMessage, sizeof(szNewMessage), g_sColors[i], sBuff);
				}
			}
		}

		Handle hBf = StartMessageOne("SayText2", iClient, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
		if(hBf != null)
		{
			if(GetUserMessageType() == UM_Protobuf)
			{
				Protobuf hProtoBuffer = UserMessageToProtobuf(hBf);
				hProtoBuffer.SetInt("ent_idx", iClient);
				hProtoBuffer.SetBool("chat", true);
				hProtoBuffer.SetString("msg_name", szNewMessage);
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
				hProtoBuffer.AddString("params", "");
			}
			else
			{
				BfWrite hBfBuffer = UserMessageToBfWrite(hBf);
				hBfBuffer.WriteByte(iClient);
				hBfBuffer.WriteByte(true);
				hBfBuffer.WriteString(szNewMessage);
			}
		}
		EndMessage();
	}
}