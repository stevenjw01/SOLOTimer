/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Basic Info Triggers Plugin
 * Implements basic information chat triggers like ff and timeleft.
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1

#include <sourcemod>
#include <csgocolors>

#undef REQUIRE_PLUGIN
#include <mapchooser>
#define REQUIRE_PLUGIN

public Plugin:myinfo = 
{
	name = "[TIMER] Basic Info Triggers",
	author = "AlliedModders LLC, DR. API Improvements",
	description = "Adds ff, timeleft, thetime, and others.",
	version = SOURCEMOD_VERSION,
	url = "http://www.sourcemod.net/"
};

ConVar g_Cvar_TriggerShow;
ConVar g_Cvar_TimeleftInterval;
ConVar g_Cvar_FriendlyFire;

Handle g_Timer_TimeShow = null;

ConVar g_Cvar_WinLimit;
ConVar g_Cvar_FragLimit;
ConVar g_Cvar_MaxRounds;

#define TIMELEFT_ALL_ALWAYS		0		/* Print to all players */
#define TIMELEFT_ALL_MAYBE		1		/* Print to all players if sm_trigger_show allows */
#define TIMELEFT_ONE			2		/* Print to a single player */

new bool:mapchooser;

new g_TotalRounds;

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basetriggers.phrases");
	
	g_Cvar_TriggerShow = CreateConVar("sm_trigger_show", "0", "Display triggers message to all players? (0 off, 1 on, def. 0)", 0, true, 0.0, true, 1.0);	
	g_Cvar_TimeleftInterval = CreateConVar("sm_timeleft_interval", "0.0", "Display timeleft every x seconds. Default 0.", 0, true, 0.0, true, 1800.0);
	g_Cvar_FriendlyFire = FindConVar("mp_friendlyfire");
	
	RegConsoleCmd("timeleft", Command_Timeleft);
	RegConsoleCmd("nextmap", Command_Nextmap);
	RegConsoleCmd("motd", Command_Motd);
	RegConsoleCmd("ff", Command_FriendlyFire);
	
	g_Cvar_TimeleftInterval.AddChangeHook(ConVarChange_TimeleftInterval);

	decl String:folder[64];   	 
   	GetGameFolderName(folder, sizeof(folder));

   	if (strcmp(folder, "insurgency") == 0)
   	{
   		HookEvent("game_newmap", Event_GameStart);
   	}
   	else
   	{
   		HookEvent("game_start", Event_GameStart);
   	}
	
	if (strcmp(folder, "nucleardawn") == 0)
	{
		HookEvent("round_win", Event_RoundEnd);
	}
	else
	{
		HookEvent("round_end", Event_RoundEnd);
	}
	
	HookEventEx("teamplay_win_panel", Event_TeamPlayWinPanel);
	HookEventEx("teamplay_restart_round", Event_TFRestartRound);
	HookEventEx("arena_win_panel", Event_TeamPlayWinPanel);
	
	g_Cvar_WinLimit = FindConVar("mp_winlimit");
	g_Cvar_FragLimit = FindConVar("mp_fraglimit");
	g_Cvar_MaxRounds = FindConVar("mp_maxrounds");
	
	mapchooser = LibraryExists("mapchooser");
}

public OnMapStart()
{
	g_TotalRounds = 0;	
}

/* Round count tracking */
public Event_TFRestartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;	
}

public Event_GameStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;	
}

public Event_TeamPlayWinPanel(Event event, const String:name[], bool:dontBroadcast)
{
	if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_TotalRounds++;
	}
}
/* You ask, why don't you just use team_score event? And I answer... Because CSS doesn't. */
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_TotalRounds++;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "mapchooser"))
	{
		mapchooser = false;
	}
}
 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "mapchooser"))
	{
		mapchooser = true;
	}
}

public ConVarChange_TimeleftInterval(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:newval = StringToFloat(newValue);
	
	if (newval < 1.0)
	{
		if (g_Timer_TimeShow != null)
		{
			KillTimer(g_Timer_TimeShow);		
		}
		
		return;
	}
	
	if (g_Timer_TimeShow != null)
	{
		KillTimer(g_Timer_TimeShow);
		g_Timer_TimeShow = CreateTimer(newval, Timer_DisplayTimeleft, _, TIMER_REPEAT);
	}
	else
		g_Timer_TimeShow = CreateTimer(newval, Timer_DisplayTimeleft, _, TIMER_REPEAT);
}

public Action:Timer_DisplayTimeleft(Handle:timer)
{
	ShowTimeLeft(0, TIMELEFT_ALL_ALWAYS);	
}

public Action:Command_Timeleft(client, args)
{
	ShowTimeLeft(client, TIMELEFT_ONE);
	
	return Plugin_Handled;
}

public Action:Command_Nextmap(client, args)
{
	if (client && !IsClientInGame(client))
		return Plugin_Handled;
	
	decl String:map[64];
	
	GetNextMap(map, sizeof(map));
	
	if (mapchooser && EndOfMapVoteEnabled() && !HasEndOfMapVoteFinished())
	{
		CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Pending Vote");			
	}
	else
	{
		CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Next Map", map);
	}
	
	return Plugin_Handled;
}

public Action:Command_Motd(client, args)
{
	if (client == 0)
	{
		CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	ShowMOTDPanel(client, "Message Of The Day", "motd", MOTDPANEL_TYPE_INDEX);

	return Plugin_Handled;
}

public Action:Command_FriendlyFire(client, args)
{
	if (client == 0)
	{
		CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (!IsClientInGame(client))
		return Plugin_Handled;
	PrintToChatAll("%N calls for ff", client);
	ShowFriendlyFire(client);

	return Plugin_Handled;
}

public OnClientSayCommand_Post(client, const String:command[], const String:sArgs[])
{
	if (strcmp(sArgs, "timeleft", false) == 0)
	{
		ShowTimeLeft(client, TIMELEFT_ALL_MAYBE);
	}
	else if (strcmp(sArgs, "thetime", false) == 0)
	{
		char ctime[64];
		FormatTime(ctime, 64, NULL_STRING);
		
		if (g_Cvar_TriggerShow.IntValue)
		{
			CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %t", "Thetime", ctime);
		}
		else
		{
			CPrintToChat(client,"[{GREEN}TIMER{NORMAL}]  %t", "Thetime", ctime);
		}
	}
	else if (strcmp(sArgs, "ff", false) == 0)
	{
		ShowFriendlyFire(client);
	}
	else if (strcmp(sArgs, "currentmap", false) == 0)
	{
		char map[64];
		GetCurrentMap(map, sizeof(map));
		
		if (g_Cvar_TriggerShow.IntValue)
		{
			CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %t", "Current Map", map);
		}
		else
		{
			PrintToChat(client,"[{GREEN}TIMER{NORMAL}]  %t", "Current Map", map);
		}
	}
	else if (strcmp(sArgs, "nextmap", false) == 0)
	{
		char map[32];
		GetNextMap(map, sizeof(map));
			
		if (g_Cvar_TriggerShow.IntValue)
		{
			if (mapchooser && EndOfMapVoteEnabled() && !HasEndOfMapVoteFinished())
			{
				CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %t", "Pending Vote");			
			}
			else
			{
				CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %t", "Next Map", map);
			}
		}
		else
		{
			if (mapchooser && EndOfMapVoteEnabled() && !HasEndOfMapVoteFinished())
			{
				CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Pending Vote");			
			}
			else
			{
				CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %t", "Next Map", map);
			}
		}
	}
	else if (strcmp(sArgs, "motd", false) == 0)
	{
		ShowMOTDPanel(client, "Message Of The Day", "motd", MOTDPANEL_TYPE_INDEX);
	}
}

ShowTimeLeft(client, who)
{
	bool lastround = false;
	bool written = false;
	bool notimelimit = false;
	
	char finalOutput[1024];
	
	if (who == TIMELEFT_ALL_ALWAYS
		|| (who == TIMELEFT_ALL_MAYBE && g_Cvar_TriggerShow.IntValue))
	{
		client = 0;	
	}
	
	new timeleft;
	if (GetMapTimeLeft(timeleft))
	{
		new mins, secs;
		new timelimit;
		
		if (timeleft > 0)
		{
			mins = timeleft / 60;
			secs = timeleft % 60;
			written = true;
			FormatEx(finalOutput, sizeof(finalOutput), "%T %d:%02d", "Timeleft", client, mins, secs);
		}
		else if (GetMapTimeLimit(timelimit) && timelimit == 0)
		{
			notimelimit = true;
		}
		else
		{
			/* 0 timeleft so this must be the last round */
			lastround=true;
		}
	}
	
	if (!lastround)
	{
		if (g_Cvar_WinLimit)
		{
			int winlimit = g_Cvar_WinLimit.IntValue;
			
			if (winlimit > 0)
			{
				if (written)
				{
					new len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (winlimit > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "WinLimitAppendPlural" ,client, winlimit);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "WinLimitAppend" ,client);
						}
					}
				}
				else
				{
					if (winlimit > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "WinLimitPlural", client, winlimit);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "WinLimit", client);
					}
					
					written = true;
				}
			}
		}
		
		if (g_Cvar_FragLimit)
		{
			int fraglimit = g_Cvar_FragLimit.IntValue;
			
			if (fraglimit > 0)
			{
				if (written)
				{
					new len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (fraglimit > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "FragLimitAppendPlural", client, fraglimit);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "FragLimitAppend", client);
						}
					}	
				}
				else
				{
					if (fraglimit > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "FragLimitPlural", client, fraglimit);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "FragLimit", client);
					}
					
					written = true;
				}			
			}
		}
		
		if (g_Cvar_MaxRounds)
		{
			int maxrounds = g_Cvar_MaxRounds.IntValue;
			
			if (maxrounds > 0)
			{
				new remaining = maxrounds - g_TotalRounds;
				
				if (written)
				{
					new len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (remaining > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "MaxRoundsAppendPlural", client, remaining);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "MaxRoundsAppend", client);
						}
					}
				}
				else
				{
					if (remaining > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "MaxRoundsPlural", client, remaining);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "MaxRounds", client);
					}
					
					written = true;
				}			
			}		
		}
	}
	
	if (lastround)
	{
		FormatEx(finalOutput, sizeof(finalOutput), "%T", "LastRound", client);
	}
	else if (notimelimit && !written)
	{
		FormatEx(finalOutput, sizeof(finalOutput), "%T", "NoTimelimit", client);
	}

	if (who == TIMELEFT_ALL_ALWAYS
		|| (who == TIMELEFT_ALL_MAYBE && g_Cvar_TriggerShow.IntValue))
	{
		CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %s", finalOutput);
	}
	else if (client != 0 && IsClientInGame(client))
	{
		CPrintToChat(client, "[{GREEN}TIMER{NORMAL}]  %s", finalOutput);
	}
	
	if (client == 0)
	{
		PrintToServer("%s", finalOutput);
	}
}

ShowFriendlyFire(client)
{
	if (g_Cvar_FriendlyFire)
	{
		char phrase[24];
		if (g_Cvar_FriendlyFire.BoolValue)
		{
			strcopy(phrase, sizeof(phrase), "Friendly Fire On");
		}
		else
		{
			strcopy(phrase, sizeof(phrase), "Friendly Fire Off");
		}
	
		if (g_Cvar_TriggerShow.IntValue)
		{
			CPrintToChatAll("[{GREEN}TIMER{NORMAL}]  %t", phrase);
		}
		else
		{
			CPrintToChat(client,"[{GREEN}TIMER{NORMAL}]  %t", phrase);
		}
	}
}