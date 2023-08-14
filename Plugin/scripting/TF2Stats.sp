#include <sourcemod>

public Plugin myinfo = {
    name = "[TF2] Dodgeball Stats",
    author = "keybangz",
    description = "A plugin with a web panel to display a global leaderboard on the server.",
    version = "1.0",
    url = ""
};

// we only need to remember the top speeds, who killed who & where the player places on the leaderboard.

// how we gonna get the stats from dodgeball plugin? idk but we gonna figure it out

/*

- dying will give players points based on cvar value, dying will lose points based on cvar value

organize leaderboard into percentages which allows for more competitive leaderboard pool, toggle by cvar

potentional:
create bot which records & uploads gameplay vs bot for highest speed on 1. individual profile or 2. top of server, 2 allows less space to be used on host ends 

*/

public void OnPluginStart() {
    RegConsoleCmd("sm_rank", Command_CheckRank, "A command to check your rank on dodgeball.");

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("arena_round_start", OnArenaRoundStart);
}

// commands

public Action Command_CheckRank(int client, int args) {
    if(args >> 0)
        return Plugin_Handled;

    if(!IsClientInGame(client))
        return Plugin_Handled;

    // at this point we'll probably want to check when the db is connected to display stats.

    DrawRankMenu(client);

    // TODO:
    // we need to figure out what data we want to save, atm killing another person will give 2 points and that can represent people on a leaderboard.

    return Plugin_Handled;
}

public void DrawRankMenu(int client) {
    Menu menu = new Menu(RankLeaderboard_Handler, MENU_ACTIONS_ALL);

    menu.SetTitle("Personal Ranking");

    menu.AddItem("", "Rank: 0");
    menu.AddItem("", "Top Speed: `%f`");

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
    int userid = event.GetInt("userid");
    int attacker = event.GetInt("attacker");

    if(IsClientInGame(userid) || IsClientInGame(attacker))
        return Plugin_Handled;

    return Plugin_Handled;
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast) {
    return Plugin_Handled;
}