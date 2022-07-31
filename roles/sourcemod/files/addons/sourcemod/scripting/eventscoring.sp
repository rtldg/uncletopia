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
ConVar g_Cvar_Enable;
ConVar g_Cvar_Region;
ConVar g_Cvar_MinPlayers;

public void OnPluginStart()
{
    CreateConVar("ut_eventscoring_version", PLUGIN_VERSION, "Event Scoring Version", FCVAR_DONTRECORD);

    g_Cvar_Enable = CreateConVar("ut_eventscoring_enable", "1.0", "Whether to enable score tracking.", _, true, 0.0, true, 1.0);
    g_Cvar_Region = CreateConVar("ut_eventscoring_region", "na", "The region this server is in.", FCVAR_DONTRECORD);
    g_Cvar_MinPlayers = CreateConVar("ut_eventscoring_minplayers", "8.0", "Minimum number of players to perform scoring.", _, true, 0.0, true, 33.0);

    // connect now and check once a minute
    char err[255];
    g_db = SQL_Connect("utevent",false,err,sizeof(err));
    if (g_db == INVALID_HANDLE) {
        ThrowError("Connection to database 'utevent' failed, error: %s", err);
    }
    SQL_SetCharset(g_db, "utf8");
    CreateTimer(60.0, MaintainDBConnection, _, TIMER_REPEAT);

    HookEvent("player_score_changed", Event_Score);
}

public Action MaintainDBConnection(Handle timer) {
    if (!g_Cvar_Enable.BoolValue) {
        return;
    }

    // there is no Database.isConnected function, so we'll try to select one row and see if it responds..
    SQL_LockDatabase(g_db);
    DBResultSet res = SQL_Query(g_db, "SELECT * FROM scores LIMIT 0,1");
    SQL_UnlockDatabase(g_db);

    char err[255];
    if (res.HasResults) {
        LogMessage("Database connection maintained");
    } else {
        g_db = SQL_Connect("utevent",false,err,sizeof(err));
        SQL_SetCharset(g_db, "utf8");
        LogMessage("Reconnected to database");
    }

    delete res;
}

public void OnClientAuthorized(int client) {
    if (!g_Cvar_Enable.BoolValue) {
        return;
    }

    char playerid[32];
    GetClientAuthId(client, AuthId_SteamID64, playerid, sizeof(playerid));

    g_Cvar_Region.GetString(g_region, sizeof(g_region));

    char query[255];
    Format(query, sizeof(query), "INSERT IGNORE INTO scores(uid64,region) VALUES(\"%s\",\"%s\")", playerid, g_region);

    SQL_TQuery(g_db, CheckQuery, query, _, DBPrio_Low);
}

public void Event_Score(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_Cvar_Enable.BoolValue) {
        return;
    }

    // only perform scoring if player count is above the minimum specified in cfg
    if (GetClientCount(false) < g_Cvar_MinPlayers.IntValue) {
        return;
    }

    char playerid[32];
    GetClientAuthId(event.GetInt("player"), AuthId_SteamID64, playerid, sizeof(playerid));

    char query[255];
    Format(query, sizeof(query), "UPDATE scores SET score = score + %d WHERE uid64 = \"%s\" AND region = \"%s\"", event.GetInt("delta"), playerid, g_region);

    SQL_TQuery(g_db, CheckQuery, query, _, DBPrio_Low);
}

// working with sourcepawn strings to have the error show up properly is agony
// so let's just... not have it show anything at all ever and just be an empty callback
void CheckQuery(Handle owner, Handle child, const char[] error, any data) {}