# AMXX Authentication
An AMXX plugin for those who seek extra security for their players and their data.

## Features
- Only username and password required for registration;
- Ability to limit the number of accounts which can be created on a single SteamID;
- Ability to punish a player for too many unsuccessful login attempts (e.g. a kick);
- Ability to punish a player for taking too long to login (e.g. a kick);
- Authentication required every time the player connects to the server;
- Passwords hashed with SHA3-512 algorithm;
- Automatic database table creation.

## Requirements
- SQL;

## Cvars
- **auth_max_accounts** <number> - number of accounts a single SteamID can create (disabled if 0) *(default: 1)*;
- **auth_max_attempts** <number> - allowed unsuccessful login attempts before punishment (disabled if 0) *(default: 3)*;
- **auth_login_time** <seconds> - given time for authenticaction before punishment (disabled if 0) *(default: 60)*;
- **auth_sql_host** <address> - database host;
- **auth_sql_user** <username> - database username;
- **auth_sql_pass** <password> - database password;
- **auth_sql_db** <name> - database name;
- **auth_sql_table** <name> - database table name;

## Installation
1. Export the downloaded files into your */addons/amxmodx/* folder;
2. Create a new database (you can use MySQL for this);
3. Open the source file */scripting/authentication.sma* and change these cvars into your SQL database settings:
```
register_cvar("auth_sql_host", "127.0.0.1", FCVAR_PROTECTED);
register_cvar("auth_sql_user", "YOUR_USER", FCVAR_PROTECTED);
register_cvar("auth_sql_pass", "YOUR_PASS", FCVAR_PROTECTED);
register_cvar("auth_sql_db", "YOUR_DB_NAME", FCVAR_PROTECTED);
register_cvar("auth_sql_table", "YOUR_TABLE_NAME", FCVAR_PROTECTED);
```
3. Compile the plugin and move it to your */addons/plugins/* folder;
4. Include the plugin in your *plugins.ini* file.

## Images
![Authentication menu in-game](https://github.com/aauga/amxx-authentication/blob/main/images/1.png?raw=true)
![Player's console after registration](https://github.com/aauga/amxx-authentication/blob/main/images/2.png?raw=true)
![Console logs](https://github.com/aauga/amxx-authentication/blob/main/images/3.png?raw=true)
![Database](https://github.com/aauga/amxx-authentication/blob/main/images/4.png?raw=true)

## Notes
Tested in Counter-Strike 1.6 on a server which uses **AMX Mod X 1.9.0.5271**. I will not provide support for older AMX Mod X versions.