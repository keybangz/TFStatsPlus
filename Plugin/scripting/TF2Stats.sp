#include <sourcemod>

public Plugin myinfo = {
    name = "[TF2] TFStats+",
    author = "keybangz",
    description = "A leaderboard plugin with rank statistics and a web panel for players to view their stats & clips(?) outside of the game.",
    version = "1.1",
    url = "https://hellhound.sydney"
};

// we only need to remember the top speeds, who killed who & where the player places on the leaderboard.

// how we gonna get the stats from dodgeball plugin? idk but we gonna figure it out

/*

- dying will give players points based on cvar value, dying will lose points based on cvar value

organize leaderboard into percentages which allows for more competitive leaderboard pool, toggle by cvar

potentional:
create bot which records & uploads gameplay vs bot for highest speed on 1. individual profile or 2. top of server, 2 allows less space to be used on host ends 

*/

Database hDatabase = null;

ConVar g_cEnableDBStats;
ConVar g_cPointGain;
ConVar g_cPointLoss;
ConVar g_cSQLDatabase;

enum struct PlayerRank {
    char name[MAXPLAYERS+1];
    int points[MAXPLAYERS+1];
    int kills[MAXPLAYERS+1];
    int deaths[MAXPLAYERS+1];
    int assists[MAXPLAYERS+1];
}

// should we be doing this on the global level? idk 
PlayerRank r;

public void OnPluginStart() {
    g_cEnableDBStats = CreateConVar("sm_tf2stats_enable", "1", "Enable TF2 Dodgeball Stats?", _, true, 0.0, true, 1.0);
    g_cPointGain = CreateConVar("sm_tf2stats_pointgain", "2", "Amount of points to give to player when they kill someone?", _, true, 0.0, false);
    g_cPointLoss = CreateConVar("sm_tf2stats_pointloss", "2", "Amount of points for player to lose when they die", _, true, 0.0, false);
    g_cSQLDatabase = CreateConVar("sm_tf2stats_db", "leaderboard", "Name of the database connecting to store player data.", _, false, _, false, _);

    RegConsoleCmd("sm_rank", Command_CheckRank, "A command to check your rank on dodgeball.");
    RegAdminCmd("sm_setpoints", Command_SetPoints, ADMFLAG_ROOT, "Give points to specified player");

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("arena_round_start", OnArenaRoundStart);

    StartSQL();
}

// implementing mysql based off wiki example
void StartSQL() {
    if(!g_cEnableDBStats.BoolValue)
        return;

    // created in memory on pluginload, in low level languages would i delete this or initialize it somewhere else? idk. 
    char dbname[64];

    // connect to db name set for databases.cfg
    g_cSQLDatabase.GetString(dbname, sizeof(dbname));

    Database.Connect(GotDatabase, dbname);
}

// connection callback
public void GotDatabase(Database db, const char[] error, any data) {
    if(db == null)
        LogError("Database failure: %s", error);

    hDatabase = db;

    char sQuery[256];

    hDatabase.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS leaderboard (id int(11) NOT NULL AUTO_INCREMENT, name varchar(128) NOT NULL, steamid varchar(32), points int(11), deaths int(11), kills int(11), assists int(11), PRIMARY KEY (id))");
    hDatabase.Query(OnSQLConnect, sQuery);
}

public void OnSQLConnect(Database db, DBResultSet results, const char[] error, any data) {
    if(results == null) 
        LogError("Query failure: %s", error);
    
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i))
            OnClientPostAdminCheck(i);
    }
}

// grab steamid from client and check if they exist in the database
public void OnClientPostAdminCheck(int client) {
    if(!g_cEnableDBStats.BoolValue)
        return;

    if(IsFakeClient(client))
        return;

    FetchPlayerInfo(client);
}

public void OnClientDisconnect(int client) {
    if(!g_cEnableDBStats.BoolValue)
        return;

    if(IsFakeClient(client))
        return;

    UpdatePlayerInfo(client);
}

void UpdatePlayerInfo(int client) {
    char sSteamID[32];
    if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
        return;

    char sQuery[255];
    FormatEx(sQuery, sizeof(sQuery), "UPDATE leaderboard SET points='%i', kills='%i', deaths='%i', assists='%i' WHERE steamid='%s'", r.points[client], r.kills[client], r.deaths[client], r.assists[client], sSteamID);
    hDatabase.Query(SQL_CatchError, sQuery);
    
    PrintToServer("[TFStats+] %N updated with %i points, %i kills, %i deaths & %i assists.", client, r.points[client], r.kills[client], r.deaths[client], r.assists[client]);
}

void FetchPlayerInfo(int client) {
    char steamid[32];
    if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
        return;

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));

    // move all fast queries to threaded queries because we can't read the wiki LOL
    // https://wiki.alliedmods.net/SQL_(SourceMod_Scripting)#Querying

    // Grab all info on database if exists, update player info then match plugin with database
    char sQuery[255];
    FormatEx(sQuery, sizeof(sQuery), "SELECT points, kills, deaths, assists FROM leaderboard WHERE steamid='%s'", steamid);
    int userid = GetClientUserId(client);
    hDatabase.Query(SQL_FetchPlayerInfo, sQuery, userid);

    // if player doesn't exist in database, create new entry with player name & steamid
    FormatEx(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `leaderboard` (`name`, `steamid`) SELECT '%s', '%s' FROM DUAL WHERE NOT EXISTS (SELECT * FROM `leaderboard` WHERE `name`='%s' AND `steamid`='%s' LIMIT 1)", name, steamid, name, steamid);
    hDatabase.Query(SQL_CatchError, sQuery);
}

void SQL_CatchError(Database db, DBResultSet results, const char[] error, any data) {
    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! error: %s", error);
        return;
    }
}

void SQL_FetchPlayerInfo(Database db, DBResultSet results, const char[] error, any data) {
    int client = 0;

    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! line: 185 error: %s", error);
        return;
    }

    if((client = GetClientOfUserId(data)) == 0)
        return;

    while(results.FetchRow()) {
        if(!SQL_IsFieldNull(results, 0))
            r.points[client] = results.FetchInt(0);

        if(!SQL_IsFieldNull(results, 1))
            r.kills[client] = results.FetchInt(1);

        if(!SQL_IsFieldNull(results, 2))
            r.deaths[client] = results.FetchInt(2);

        if(!SQL_IsFieldNull(results, 3))
            r.assists[client] = results.FetchInt(3);
    }

    PrintToServer("[TFStats+] %N has %i points, %i kills, %i deaths, %i assists.", client, r.points[client], r.kills[client], r.deaths[client], r.assists[client]);
}

// commands

public Action Command_SetPoints(int client, int args) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    char sSteamID[32];
    if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
        return Plugin_Handled;

    char points[100];
    GetCmdArg(1, points, sizeof(points));

    r.points[client] = StringToInt(points);

    char sQuery[256]; 
    FormatEx(sQuery, sizeof(sQuery), "UPDATE leaderboard SET points='%i' WHERE steamid='%s'", r.points[client], sSteamID);
    hDatabase.Query(SQL_CatchError, sQuery);

    PrintToChat(client, "[TFStats+] Set leaderboard points to %s r.points: %i", points, r.points[client]);

    return Plugin_Handled;
}

public Action Command_CheckRank(int client, int args) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    if(args >> 0)
        return Plugin_Handled;

    char sSteamID[32];
    if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
        return Plugin_Handled;

    DrawRankMenu(client, sSteamID);
    UpdatePlayerInfo(client);

    return Plugin_Handled;
}

public void DrawRankMenu(int client, char[] sSteamID) {
    Menu menu = new Menu(RankLeaderboard_Handler, MENU_ACTIONS_ALL);

    char sPlayerName[64];

    Format(sPlayerName, sizeof(sPlayerName), "%N's leaderboard", client);

    menu.SetTitle(sPlayerName);
    
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Points: %i", r.points[client]);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Kills: %i", r.kills[client]);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Deaths: %i", r.deaths[client]);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Assists: %i", r.assists[client]);
    menu.AddItem("", sBuffer);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}


// events

public int RankLeaderboard_Handler(Menu menu, MenuAction action, int param1, int param2) {
    switch(action) {
        case MenuAction_Select: {
            char info[24];
            GetMenuItem(menu, param2, info, sizeof(info));   
        }
    }

    return 0;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    int userid = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int assist = GetClientOfUserId(event.GetInt("assister"));

    if(!IsClientInGame(userid) || !IsClientInGame(attacker))
        return Plugin_Handled;

    if(userid == attacker) // don't count suicide stats
        return Plugin_Handled;

    //if(IsFakeClient(attacker)) FIXME: UNCOMMENT LATER
        //return Plugin_Handled;

    PrintToChat(userid, "[TFStats+] You have lost %i points for dying to %N.", g_cPointLoss.IntValue, attacker);
    PrintToChat(attacker, "[TFStats+] You have gained %i points for killing %N.", g_cPointGain.IntValue, userid);

    int pointsW = r.points[attacker] + g_cPointGain.IntValue;
    int pointsL = r.points[userid] - g_cPointLoss.IntValue;

    r.points[attacker] = pointsW;
    r.points[userid] = pointsL;

    r.kills[attacker]++;
    r.deaths[userid]++;

    if(assist >> 0 && assist < MaxClients) {
        if(IsClientInGame(assist)) {
            r.assists[assist]++;
            r.points[assist]++;
            PrintToChat(assist, "[TFStats+] You have gained 1 point for assisting %N", attacker);
        }   
    }

    UpdatePlayerInfo(userid);

    return Plugin_Handled;
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    return Plugin_Handled;
}