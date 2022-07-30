#pragma semicolon 1

#define PLUGIN_AUTHOR "raspy"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "Uncletopia Event Scoring",
	author = PLUGIN_AUTHOR,
	description = "Plugin to handle event scoring.",
	version = PLUGIN_VERSION,
	url = "https://uncletopia.com"
}

Database g_db;
char g_region[8];
ConVar g_Cvar_Region;
ConVar g_Cvar_MinPlayers;

public void OnPluginStart()
{
    CreateConVar("ut_eventscoring_version", PLUGIN_VERSION, "Event Scoring Version", FCVAR_DONTRECORD);

    g_Cvar_Region = CreateConVar("ut_eventscoring_region", "na", "The region this server is in.", FCVAR_DONTRECORD);
    g_Cvar_MinPlayers = CreateConVar("ut_eventscoring_minplayers", "8.0", "Minimum number of players to perform scoring.", _, true, 0.0, true, 33.0);

    char err[255];
    g_db = SQL_Connect("utevent",false,err,sizeof(err));
    if (g_db == INVALID_HANDLE) {
        ThrowError("Connection to database 'utevent' failed, error: %s", err);
    }
    SQL_SetCharset(g_db, "utf8");

    HookEvent("player_score_changed", Event_Score);
}

public void OnClientAuthorized(int client) {
    char playerid[32];
    GetClientAuthId(client, AuthId_SteamID64, playerid, sizeof(playerid));

    g_Cvar_Region.GetString(g_region, sizeof(g_region));

    char query[255];
    Format(query, sizeof(query), "INSERT IGNORE INTO scores(uid64,region) VALUES(\"%s\",\"%s\")", playerid, g_region);

    if (!SQL_FastQuery(g_db, query)) {
        char error[255];
        SQL_GetError(g_db, error, sizeof(error));
        LogMessage("Failed to add player to UT event score list (error: %s)", error);
    }
}

public void Event_Score(Event event, const char[] name, bool dontBroadcast)
{
    // only perform scoring if player count is above the minimum specified in cfg
    if (GetClientCount(false) < g_Cvar_MinPlayers.IntValue) {
        return;
    }

    char playerid[32];
    GetClientAuthId(event.GetInt("player"), AuthId_SteamID64, playerid, sizeof(playerid));

    char query[255];
    Format(query, sizeof(query), "UPDATE scores SET score = score + %d WHERE uid64 = \"%s\" AND region = \"%s\"", event.GetInt("delta"), playerid, g_region);

    if (!SQL_FastQuery(g_db, query)) {
        char error[255];
        SQL_GetError(g_db, error, sizeof(error));
        LogMessage("Failed to update UT event player score (error: %s)", error);
    }
}