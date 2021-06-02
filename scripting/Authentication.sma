#include <amxmodx>
#include <amxconst>
#include <string>
#include <sqlx>

#define MAX_PLAYERS 32
#define MAX_LENGTH 64

new cvar_max_accounts, cvar_max_attempts, cvar_login_time;

// SQL variables
new Handle:g_SqlTuple;
new auth_sql_host[MAX_LENGTH], auth_sql_user[MAX_LENGTH], auth_sql_pass[MAX_LENGTH], auth_sql_db[MAX_LENGTH], auth_sql_table[MAX_LENGTH];

new g_Username[MAX_PLAYERS][MAX_LENGTH], bool:g_UsernameAvailable[MAX_PLAYERS], g_Password[MAX_PLAYERS][MAX_LENGTH];
new g_LoginAttempts[MAX_PLAYERS], g_TimeLeft[MAX_PLAYERS];
new bool:g_CanRegister[MAX_PLAYERS], bool:g_LoggedIn[MAX_PLAYERS];

public plugin_init()
{
	register_plugin("Authentication", "1.0", "aauga");
	register_dictionary("authentication.txt");

	cvar_max_accounts = register_cvar("auth_max_accounts", "1");	// Max accounts a single SteamID can have. 0 - disabled
	cvar_max_attempts = register_cvar("auth_max_attempts", "3"); 	// Max login attempts before kick. 0 - disabled
	cvar_login_time = register_cvar("auth_login_time", "60");		// Max login time in seconds before kick. 0 - disabled

	register_cvar("auth_sql_host", "", FCVAR_PROTECTED);
	register_cvar("auth_sql_user", "", FCVAR_PROTECTED);
	register_cvar("auth_sql_pass", "", FCVAR_PROTECTED);
	register_cvar("auth_sql_db", "", FCVAR_PROTECTED);
	register_cvar("auth_sql_table", "", FCVAR_PROTECTED);

	get_cvar_string("auth_sql_host", auth_sql_host, charsmax(auth_sql_host));
	get_cvar_string("auth_sql_user", auth_sql_user, charsmax(auth_sql_user));
	get_cvar_string("auth_sql_pass", auth_sql_pass, charsmax(auth_sql_pass));
	get_cvar_string("auth_sql_db", auth_sql_db, charsmax(auth_sql_db));
	get_cvar_string("auth_sql_table", auth_sql_table, charsmax(auth_sql_table));

	register_clcmd("EnterUsername", "handleUsernameInput");
	register_clcmd("EnterPassword", "handlePasswordInput");

	register_message(get_user_msgid("ShowMenu"), "handleChooseTeamMenu");
	register_message(get_user_msgid("VGUIMenu"), "handleChooseTeamMenu");

	sql_createTuple();
	sql_createTable();
}

public plugin_end()
{
	SQL_FreeHandle(g_SqlTuple);
}

public client_connect(id)
{
	g_Username[id] = "";
	g_Password[id] = "";

	g_UsernameAvailable[id] = false;
	g_CanRegister[id] = true;
	g_LoginAttempts[id] = 0;

	g_LoggedIn[id] = is_user_bot(id) ? true : false;
	g_TimeLeft[id] = get_pcvar_num(cvar_login_time);
}

public client_authorized(id)
{
	if(get_pcvar_num(cvar_max_accounts) != 0)
	{
		// Check if user can create new accounts when SteamID is assigned
		sql_checkCanUserRegister(id);
	}
}

public client_putinserver(id)
{
	if(get_pcvar_num(cvar_login_time) != 0)
	{
		// Start login timer when user sees MOTD
		loginTimer(id);
	}
}

public client_disconnected(id)
{
	g_Username[id] = "";
	g_Password[id] = "";
	g_LoggedIn[id] = false;
	g_CanRegister[id] = true;
	g_UsernameAvailable[id] = false;
	g_TimeLeft[id] = 0;
	g_LoginAttempts[id] = 0;
}

public handleChooseTeamMenu(iMsgid, iDest, id)
{
	if(g_LoggedIn[id])
	{
		return PLUGIN_CONTINUE;
	}

	authenticationMenu(id);

	return PLUGIN_HANDLED;
}

/*===========================
		Login menu
===========================*/

public authenticationMenu(id)
{
	new buffer[128];

	formatex(buffer, charsmax(buffer), "\r%L %L", id, "PREFIX", id, "LOGIN_MENU_TITLE");
	new menu = menu_create(buffer, "handleAuthenticationMenu");

	addUsernameItemToMenu(id, menu, buffer);
	addPasswordItemToMenu(id, menu, buffer);
	addAuthItemToMenu(id, menu, buffer);

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu, 0);
}

addUsernameItemToMenu(id, menu, buffer[128])
{
	formatex(buffer, charsmax(buffer), "%L: \d%s", id, "USERNAME", equal(g_Username[id], "") ? "-" : g_Username[id]);
	menu_additem(menu, buffer, g_Username[id], 0);
}

addPasswordItemToMenu(id, menu, buffer[128])
{
	new hiddenPassword[MAX_LENGTH];
	new passwordLength = strlen(g_Password[id]);

	// Hide password in the menu with *
	for(new i = 0; i < passwordLength; i++)
	{
		formatex(hiddenPassword, charsmax(hiddenPassword), "%s*", hiddenPassword);
	}

	formatex(buffer, charsmax(buffer), "%L: \d%s", id, "PASSWORD", equal(g_Password[id], "") ? "-" : hiddenPassword);
	menu_additem(menu, buffer, g_Password[id], 0);
}

addAuthItemToMenu(id, menu, buffer[128])
{
	if(!equal(g_Username[id], "") && !equal(g_Password[id], ""))
	{
		menu_addblank(menu, 0);

		formatex(buffer, charsmax(buffer), "%L", id, g_UsernameAvailable[id] ? "REGISTER" : "LOGIN");
		menu_additem(menu, buffer, "", 0);
	}
}

public handleAuthenticationMenu(id, menu, item)
{
	switch(item)
	{
		case 0:
        {
            client_cmd(id, "messagemode EnterUsername");
        }
        case 1:
        {
            client_cmd(id, "messagemode EnterPassword");
        }
		case 2:
		{
			if(g_UsernameAvailable[id])
			{
				if(g_CanRegister[id])
				{
					sql_createAccount(id);
				}
				else
				{
					client_print(id, print_center, "%L", id, "TOO_MANY_ACCOUNTS");
					authenticationMenu(id);
				}
			}
			else
			{
				sql_checkPassword(id);
			}

			if(g_LoggedIn[id])
			{
				client_cmd(id, "chooseteam");
			}
		}
	}

	return PLUGIN_HANDLED;
}

/*===========================
		SQL functions
===========================*/

stock sql_createTuple()
{
	g_SqlTuple = SQL_MakeDbTuple(auth_sql_host, auth_sql_user, auth_sql_pass, auth_sql_db);

	if(g_SqlTuple == Empty_Handle)
	{
		// Stop plugin because of failure
		set_fail_state("Failed to create database tuple.");
	}
}

/**
 * Function opens a database connection 
 *
 * @return SQL connection handle
 */
stock Handle:sql_connectToDatabase()
{
	new sqlErrorCode, sqlError[128];
	new Handle:connection = SQL_Connect(g_SqlTuple, sqlErrorCode, sqlError, charsmax(sqlError));

	// If SQL connection to the database was successful
	if(connection == Empty_Handle)
	{
		// Stop plugin because of failure
		set_fail_state("Failed to connect to database. Error #%i: %s", sqlErrorCode, sqlError);
	}

	return connection;
}

// Create a table if it doesn't exist in the database
stock sql_createTable()
{
	new Handle:connection = sql_connectToDatabase();

	// If SQL connection to the database was successful
	if(connection != Empty_Handle)
	{
		new Handle:query = SQL_PrepareQuery(connection, "CREATE TABLE IF NOT EXISTS %s (`username` VARCHAR(64) NOT NULL, `password` VARCHAR(128) NOT NULL, `steamid` VARCHAR(34) NOT NULL, PRIMARY KEY (`username`));", auth_sql_table);

		// If SQL query failed
		if(SQL_Execute(query) == 0)
		{
			new errorMsg[256];
			SQL_QueryError(query, errorMsg, charsmax(errorMsg));

			// Stop plugin because of failure
			set_fail_state("Could not create table. Error: %s", errorMsg);
		}
		else
		{
			log_amx("Successfully found table `%s`.", auth_sql_table);
		}
	}

	SQL_FreeHandle(connection);
}

// Check if an account isn't already created with this username
stock sql_isUsernameAvailable(id)
{
	new Handle:connection = sql_connectToDatabase();

	// If SQL connection to the database was successful
	if(connection != Empty_Handle)
	{
		new Handle:query = SQL_PrepareQuery(connection, "SELECT NULL FROM %s WHERE (`username` = '%s')", auth_sql_table, g_Username[id]);

		// If SQL query failed
		if(SQL_Execute(query) == 0)
		{
			// Print error to the console
			new errorMsg[256];
			SQL_QueryError(query, errorMsg, charsmax(errorMsg));
			log_amx("Could not execute query. Error: %s", errorMsg);

			// Print error to the user, reopen menu
			client_print(id, print_center, "%L", id, "FAILED_USERNAME_CHECK");
			authenticationMenu(id);
		}
		else
		{
			// Check availability
			g_UsernameAvailable[id] = (SQL_NumResults(query) == 0 ? true : false);
		}
	}

	SQL_FreeHandle(connection);
}

stock sql_createAccount(id)
{
	new Handle:connection = sql_connectToDatabase();

	// If SQL connection to the database was successful
	if(connection != Empty_Handle)
	{
		// Get user's SteamID
		new authID[34];
		get_user_authid(id, authID, charsmax(authID));

		new Handle:query = SQL_PrepareQuery(connection, "INSERT INTO %s VALUES ('%s', '%s', '%s');", auth_sql_table, g_Username[id], hashPassword(g_Password[id]), authID);

		// If SQL query failed
		if(SQL_Execute(query) == 0)
		{
			// Print error to the console
			new errorMsg[256];
			SQL_QueryError(query, errorMsg, charsmax(errorMsg));
			log_amx("Could not create account. Error: %s", errorMsg);

			// Print error to the user, reopen menu
			client_print(id, print_center, "%L", id, "FAILED_ACCOUNT_CREATION");
			authenticationMenu(id);
		}
		else
		{
			g_LoggedIn[id] = true;

			log_amx("Player '%s' (%s) successfully created an account.", g_Username[id], authID);

			// Print information to the user
			client_print(id, print_console, "^n=================================================");
			client_print(id, print_console, "%L", id, "CONSOLE_INFO");
			client_print(id, print_console, " • %L: %s", id, "USERNAME", g_Username[id]);
			client_print(id, print_console, " • %L: %s", id, "PASSWORD", g_Password[id]);
			client_print(id, print_console, " • SteamID: %s", authID);
			client_print(id, print_console, "=================================================^n");

			client_print_color(id, id, "^4%L ^1%L", id, "PREFIX", id, "ACCOUNT_CREATED");
		}
	}

	SQL_FreeHandle(connection);
}

// Check if a user's password matches the one in the database
stock sql_checkPassword(id)
{
	new Handle:connection = sql_connectToDatabase();

	// If SQL connection to the database was successful
	if(connection != Empty_Handle)
	{
		new Handle:query = SQL_PrepareQuery(connection, "SELECT `password` FROM %s WHERE (`username` = '%s')", auth_sql_table, g_Username[id]);

		// If SQL query failed
		if(SQL_Execute(query) == 0)
		{
			// Print error to the console
			new errorMsg[256];
			SQL_QueryError(query, errorMsg, charsmax(errorMsg));
			log_amx("Could not check password. Error: %s", errorMsg);

			// Print error to the user, reopen menu
			client_print(id, print_center, "%L", id, "FAILED_PASSWORD_CHECK");
			authenticationMenu(id);
		}
		else
		{
			new dbPassword[128];
			SQL_ReadResult(query, 0, dbPassword, charsmax(dbPassword));

			// If entered password matches the one in the database
			if(equali(hashPassword(g_Password[id]), dbPassword))
			{
				g_LoggedIn[id] = true;

				new authID[34];
				get_user_authid(id, authID, charsmax(authID));

				log_amx("Player '%s' (%s) successfully logged in.", g_Username[id], authID);
				client_print_color(id, id, "^4%L ^1%L", id, "PREFIX", id, "LOGGED_IN");
			}
			else
			{
				// Increase login attempts, if enabled
				if(get_pcvar_num(cvar_max_attempts) != 0)
				{
					g_LoginAttempts[id]++;

					if(g_LoginAttempts[id] == get_pcvar_num(cvar_max_attempts))
					{
						server_cmd("kick #%d Too many login attempts. Please try again.", get_user_userid(id));
					}

					client_print(id, print_center, "%L", id, "WRONG_PASSWORD_WARNING", get_pcvar_num(cvar_max_attempts) - g_LoginAttempts[id]);
				}
				else
				{
					client_print(id, print_center, "%L", id, "WRONG_PASSWORD");
				}

				authenticationMenu(id);
			}
		}
	}

	SQL_FreeHandle(connection);
}

// Check if a user can create a new account by calculating SteamID rows in the database
stock sql_checkCanUserRegister(id)
{
	new Handle:connection = sql_connectToDatabase();

	// If SQL connection to the database was successful
	if(connection != Empty_Handle)
	{
		// Get user's SteamID
		new authID[34];
		get_user_authid(id, authID, charsmax(authID));

		new Handle:query = SQL_PrepareQuery(connection, "SELECT NULL FROM %s WHERE (`steamid` = '%s')", auth_sql_table, authID);

		// If SQL query failed
		if(SQL_Execute(query) == 0)
		{
			// Print error to the console
			new errorMsg[256];
			SQL_QueryError(query, errorMsg, charsmax(errorMsg));
			log_amx("Could not check SteamID. Error: %s", errorMsg);

			// Print error to the user, reopen menu
			client_print(id, print_center, "%L", id, "FAILED_STEAMID_CHECK");
			authenticationMenu(id);
		}
		else if(SQL_NumResults(query) >= get_pcvar_num(cvar_max_accounts))
		{
			g_CanRegister[id] = false;
		}
	}

	SQL_FreeHandle(connection);
}

/*===========================
		Other functions
===========================*/

/**
 * Function hashes password with SHA3-512 algorithm
 *
 * @param password	Plain text password
 * @return Hashed password
 */
hashPassword(password[MAX_LENGTH])
{
	new hashed[128];

	hash_string(password, Hash_Sha3_512, hashed, charsmax(hashed));

	return hashed;
}

// Function for checking how long a user is logging in 
public loginTimer(id)
{
	if(!g_LoggedIn[id])
	{
		if(g_TimeLeft[id] > 0)
		{
			if(g_TimeLeft[id] % 10 == 0)
			{
				client_print(id, print_center, "%L", id, "LOGIN_TIME_WARNING", g_TimeLeft[id]);
			}

			g_TimeLeft[id]--;

			set_task(1.0, "loginTimer", id);
		}
		else
		{
			server_cmd("kick #%d 'Login time expired. Please try again.'", get_user_userid(id));
		}
	}
}

public handleUsernameInput(id)
{
	read_args(g_Username[id], charsmax(g_Username));
	remove_quotes(g_Username[id]);
	trim(g_Username[id]);

	sql_isUsernameAvailable(id);

	authenticationMenu(id);
}

public handlePasswordInput(id)
{
	read_args(g_Password[id], charsmax(g_Password));
	remove_quotes(g_Password[id]);
	trim(g_Password[id]);

	authenticationMenu(id);
}