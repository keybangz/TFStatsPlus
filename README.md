# TF2Stats+
A Team Fortress 2 plugin aimed to be a replacement for the popular [**[TF2] Ranking and Item Logger**](https://forums.alliedmods.net/showthread.php?p=987696). This plugin was made in my own time as a challenge to try something new, especially designing a modern web panel with a nice default look.

**CONTEXT LINKS**
[Plugin](#Plugin)
[Web Panel](#Web-Panel)
[MySQL](#MySQL)

# Plugin

## Features

The general gameplay logging goes like this:
`X` player dies to `Y` - **Player Y gains `ConVarValue` points, Player X loses `ConVarValue` points.** 

At the current time, the plugin does not track events such as air blasting, destroying buildings, etc. See (TODO: Add issue for plugin development)
## ConVars

`sm_tf2stats_enable (def: 1)`  - Enable or disable the plugin?
`sm_tf2stats_pointgain (def: 2)`  - How many points does a player gain for killing another player?
`sm_tf2stats_pointloss (def: 2)`  - How many points does a player lose for dying to another player?
`sm_tf2stats_db (def: leaderboard)` - Name of database entry in databases.cfg.
`sm_tf2stats_table (def: tf2statsplus)` - Name of table generated in database by plugin.
## Commands

`sm_rank` (!rank) - Display the rank menu which displays the current clients stats.
`sm_top` (!top) - Display the top 100 leaderboard according to the latest SELECT query on the database.
## In-Game leaderboard

![image](https://github.com/keybangz/TFStatsPlus/assets/23132897/c8961676-b63d-4bef-8e1e-3a81f7d755c1)
![image](https://github.com/keybangz/TFStatsPlus/assets/23132897/2879c444-3939-4be2-b937-155f51498e63)

### Select other players stats!
![image](https://github.com/keybangz/TFStatsPlus/assets/23132897/38a2acf0-619b-4d69-97ac-af1d0f9c3710)

# Web-Panel

# Placeholder Leaderboard

![image](https://github.com/keybangz/TF2_Dodgeball_Stats/assets/23132897/e8966b4a-4a14-4b6a-95ca-9ad3c578880b)
## MySQL

![image](https://github.com/keybangz/TFStatsPlus/assets/23132897/07433592-080b-4b3d-aebd-fb3eed2e0f07)


