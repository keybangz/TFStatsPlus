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
ConVar g_cTableName;

enum struct PlayerRank {
    char name[MAXPLAYERS+1];
    int points[MAXPLAYERS+1];
    int kills[MAXPLAYERS+1];
    int deaths[MAXPLAYERS+1];
    int assists[MAXPLAYERS+1];
}

PlayerRank r;
ArrayList topPlayerList = null;
ArrayList topSteamIDList = null;

public void OnPluginStart() {
    g_cEnableDBStats = CreateConVar("sm_tf2stats_enable", "1", "Enable TF2 Dodgeball Stats?", _, true, 0.0, true, 1.0);
    g_cPointGain = CreateConVar("sm_tf2stats_pointgain", "2", "Amount of points to give to player when they kill someone?", _, true, 0.0, false);
    g_cPointLoss = CreateConVar("sm_tf2stats_pointloss", "2", "Amount of points for player to lose when they die", _, true, 0.0, false);
    g_cSQLDatabase = CreateConVar("sm_tf2stats_db", "leaderboard", "Name of the database connecting to store player data.", _, false, _, false, _);
    g_cTableName = CreateConVar("sm_tf2stats_table", "tf2statsplus", "Name of the table holding the player data in the database.", _, false, _, false, _);

    RegConsoleCmd("sm_rank", Command_CheckRank, "A command to check your rank.");
    RegConsoleCmd("sm_top", Command_ShowLeaderboard, "A command to show 100 player leaderboard.");
    RegAdminCmd("sm_setpoints", Command_SetPoints, ADMFLAG_ROOT, "Give points to specified player");

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("arena_round_start", OnArenaRoundStart);

    // thanks baddie
    topPlayerList = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
    topSteamIDList = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));

    StartSQL();
}

// implementing mysql based off wiki example
void StartSQL() {
    if(!g_cEnableDBStats.BoolValue)
        return;

    char dbname[64];
    g_cSQLDatabase.GetString(dbname, sizeof(dbname));

    Database.Connect(GotDatabase, dbname);
}

// connection callback
public void GotDatabase(Database db, const char[] error, any data) {
    if(db == null)
        LogError("Database failure: %s", error);

    hDatabase = db;

    char sQuery[256];
    char buffer[256];

    g_cTableName.GetString(buffer, sizeof(buffer));
    FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS %s (id int(11) NOT NULL AUTO_INCREMENT, name varchar(128) NOT NULL, steamid varchar(32), points int(11), deaths int(11), kills int(11), assists int(11), PRIMARY KEY (id))", buffer);
    hDatabase.Query(OnSQLConnect, sQuery);

    FormatEx(sQuery, sizeof(sQuery), "SELECT name, points, steamid FROM %s ORDER BY points DESC LIMIT 100", buffer);
    hDatabase.Query(SQL_Leaderboard, sQuery);
}

public void OnSQLConnect(Database db, DBResultSet results, const char[] error, any data) {
    if(results == null) 
        LogError("Query failure: %s", error);
    
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i))
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
    char buffer[256];

    g_cTableName.GetString(buffer, sizeof(buffer));
    FormatEx(sQuery, sizeof(sQuery), "UPDATE %s SET points='%i', kills='%i', deaths='%i', assists='%i' WHERE steamid='%s'", buffer, r.points[client], r.kills[client], r.deaths[client], r.assists[client], sSteamID);
    hDatabase.Query(SQL_CatchError, sQuery);
    
    PrintToServer("[TFStats+] %N updated with %i points, %i kills, %i deaths & %i assists.", client, r.points[client], r.kills[client], r.deaths[client], r.assists[client]);
}

void FetchPlayerInfo(int client) {
    char steamid[32];
    if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
        return;

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));

    char sQuery[255];
    char buffer[256];

    g_cTableName.GetString(buffer, sizeof(buffer));
    FormatEx(sQuery, sizeof(sQuery), "SELECT points, kills, deaths, assists FROM %s WHERE steamid='%s'", buffer, steamid);
    int userid = GetClientUserId(client);
    hDatabase.Query(SQL_FetchPlayerInfo, sQuery, userid);

    // if player doesn't exist in database, create new entry with player name & steamid
    FormatEx(sQuery, sizeof(sQuery), "INSERT IGNORE INTO `%s` (`name`, `steamid`) SELECT '%s', '%s' FROM DUAL WHERE NOT EXISTS (SELECT * FROM `%s` WHERE `name`='%s' AND `steamid`='%s' LIMIT 1)", buffer, name, steamid, buffer, name, steamid);

    hDatabase.Query(SQL_CatchError, sQuery);
}

void SQL_CatchError(Database db, DBResultSet results, const char[] error, any data) {
    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! error: %s", error);
        return;
    }
}

void SQL_Leaderboard(Database db, DBResultSet results, const char[] error, any data) {
    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! error: %s", error);
        return;
    }

    char buffer[256];
    PrintToServer("[DEBUG] SQL_Leaderboard():results.RowCount is %i", results.RowCount);

    for(int i = 0; i < results.RowCount; i++) {
        while(results.FetchRow()) {
            if(!SQL_IsFieldNull(results, 0)) {
                results.FetchString(0, buffer, sizeof(buffer));
                
                // if we already have the name in our list, don't add another one.
                if(topPlayerList.FindString(buffer) != -1)
                    return;

                topPlayerList.PushString(buffer);
                PrintToServer("[DEBUG] SQL_Leaderboard(): %s added to topPlayerList", buffer);
            }
            else {
                PrintToServer("[TFStats+] No results returned for SQL_Leaderboard():topPlayerList");
                return; 
            }

            if(!SQL_IsFieldNull(results, 2)) {
                results.FetchString(2, buffer, sizeof(buffer));

                // if we already have the steamid in our list, don't add another one.
                if(topSteamIDList.FindString(buffer) != -1)
                    return;

                topSteamIDList.PushString(buffer);
                PrintToServer("[DEBUG] SQL_Leaderboard(): %s added to topSteamID", buffer);
            }
            else {
                PrintToServer("[TFStats+] No results returned for SQL_Leaderboard():topSteamIDList");       
                return;
            }
        }
    }
}

void SQL_FetchPlayerInfo(Database db, DBResultSet results, const char[] error, any data) {
    int client = 0;

    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! error: %s", error);
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

void SQL_FetchOtherPlayerInfo(Database db, DBResultSet results, const char[] error, any data) {
    int client = 0;
    int points,kills,deaths,assists;
    char name[64];

    if(db == null || results == null || error[0] != '\0') {
        LogError("Query failed! error: %s", error);
        return;
    }

    if((client = GetClientOfUserId(data)) == 0)
        return;

    while(results.FetchRow()) {
        if(!SQL_IsFieldNull(results, 0))
            points = results.FetchString(0, name, sizeof(name));

        if(!SQL_IsFieldNull(results, 1))
            points = results.FetchInt(1);

        if(!SQL_IsFieldNull(results, 2))
            kills = results.FetchInt(2);

        if(!SQL_IsFieldNull(results, 3))
            deaths = results.FetchInt(3);

        if(!SQL_IsFieldNull(results, 4))
            assists = results.FetchInt(4);
    }

    // Once leaderboard player data is fetched, we'll display a replica of the same menu we use for our personal player.
    DrawOtherRankMenu(client, name, points, kills, deaths, assists);
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
    char buffer[256];

    g_cTableName.GetString(buffer, sizeof(buffer));
    FormatEx(sQuery, sizeof(sQuery), "UPDATE %s SET points='%i' WHERE steamid='%s'", buffer, r.points[client], sSteamID);
    hDatabase.Query(SQL_CatchError, sQuery);

    PrintToChat(client, "[TFStats+] Set leaderboard points to %s r.points: %i", points, r.points[client]);

    return Plugin_Handled;
}

public Action Command_CheckRank(int client, int args) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    if(args > 0)
        return Plugin_Handled;

    char sSteamID[32];
    if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
        return Plugin_Handled;

    DrawRankMenu(client, sSteamID);
    UpdatePlayerInfo(client);

    return Plugin_Handled;
}

public Action Command_ShowLeaderboard(int client, int args) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    if(args > 0)
        return Plugin_Handled;

    char sQuery[256];
    char buffer[64];
    g_cTableName.GetString(buffer, sizeof(buffer));
    FormatEx(sQuery, sizeof(sQuery), "SELECT name, points, steamid FROM %s ORDER BY points DESC LIMIT 100", buffer);
    hDatabase.Query(SQL_Leaderboard, sQuery);

    DrawLeaderboardMenu(client);

    return Plugin_Handled;
}

public void DrawRankMenu(int client, char[] sSteamID) {
    Menu menu = new Menu(RankMenu_Handler, MENU_ACTIONS_ALL);

    char sPlayerName[64];

    Format(sPlayerName, sizeof(sPlayerName), "%N's leaderboard", client);

    menu.SetTitle(sPlayerName);
    
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Top Leaderboard");
    menu.AddItem("leaderboard", sBuffer);
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

public void DrawOtherRankMenu(int client, char[] sPlayerName, int iPoints, int iKills, int iDeaths, int iAssists) {
    Menu menu = new Menu(RankMenu_Handler, MENU_ACTIONS_ALL);

    char sMenuTitle[64];

    Format(sMenuTitle, sizeof(sMenuTitle), "%s's leaderboard", sPlayerName);

    menu.SetTitle(sMenuTitle);
    
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Top Leaderboard");
    menu.AddItem("leaderboard", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Points: %i", iPoints);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Kills: %i", iKills);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Deaths: %i", iDeaths);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Assists: %i", iAssists);
    menu.AddItem("", sBuffer);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void DrawLeaderboardMenu(int client) {
    Menu menu = new Menu(Leaderboard_Handler, MENU_ACTIONS_ALL);

    // We'll want to look through top 100 players and grab their names, add them to the menu.
    // Upon selecting a client on the menu, show a rank menu which is the same as our client.

    menu.SetTitle("Top 100 Leaderboard");

    char name[64];
    char steamid[64];

    PrintToServer("[DEBUG] DrawLeaderboardMenu():topPlayerList size: %i", topPlayerList.Length);

    for(int i = 0; i < sizeof(topPlayerList.Length); i++) {
        topPlayerList.GetString(i, name, sizeof(name));
        topSteamIDList.GetString(i, steamid, sizeof(steamid));

        PrintToServer("[SM] Player Found: %s, %s", name, steamid);
        menu.AddItem(steamid, name);
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}


// events

public int RankMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
    switch(action) {
        case MenuAction_Select: {
            char info[24];
            GetMenuItem(menu, param2, info, sizeof(info));  

            if(StrEqual(info, "leaderboard"))   {
                DrawLeaderboardMenu(param1);
            }
        }
    }

    return 0;
}

public int Leaderboard_Handler(Menu menu, MenuAction action, int param1, int param2) {
    switch(action) {
        case MenuAction_Select: {
            char info[24];
            GetMenuItem(menu, param2, info, sizeof(info));
            char steamid[64];
            int userid = GetClientUserId(param1);

            for(int i = 0; i < sizeof(topSteamIDList.Length); i++) {
                topSteamIDList.GetString(i, steamid, sizeof(steamid));

                if(StrEqual(info, steamid)) {
                    char sQuery[255];
                    char buffer[256];

                    g_cTableName.GetString(buffer, sizeof(buffer));
                    FormatEx(sQuery, sizeof(sQuery), "SELECT name, points, kills, deaths, assists FROM %s WHERE steamid='%s'", buffer, steamid);
                    hDatabase.Query(SQL_FetchOtherPlayerInfo, sQuery, userid);
                }
            }
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

    int pointsW = r.points[attacker] + g_cPointGain.IntValue;
    int pointsL = r.points[userid] - g_cPointLoss.IntValue;

    if(pointsL > 0) {
        r.points[userid] = pointsL;
        PrintToChat(userid, "[TFStats+] You have lost %i points for dying to %N.", g_cPointLoss.IntValue, attacker);
    }
    else
        r.points[userid] = 0;

    r.points[attacker] = pointsW;

    r.kills[attacker]++;
    r.deaths[userid]++;

    if(assist > 0 && assist < MaxClients) {
        if(IsClientInGame(assist)) {
            r.assists[assist]++;
            r.points[assist]++;
            PrintToChat(assist, "[TFStats+] You have gained 1 point for assisting %N", attacker);
        }   
    }

    PrintToChat(attacker, "[TFStats+] You have gained %i points for killing %N.", g_cPointGain.IntValue, userid);

    UpdatePlayerInfo(userid);

    return Plugin_Handled;
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if(!g_cEnableDBStats.BoolValue)
        return Plugin_Handled;

    return Plugin_Handled;
}