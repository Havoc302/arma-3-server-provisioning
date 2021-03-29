#Requires -RunAsAdministrator
# Must run as administrator to create the Symlinks between the mods and the server directory. It will also add the Windows Firewall Rules for you.

# Do you wish this script to run unattended (on a scheduled task)? Switch to false to be prompted to enter credential on every script run and prompted for each action.
# This will NOT work with an account that has Steam Guard enabled.
# Set this to false for the first run to get it all setup.
$unattended = $false

# Switch this off if you don't want the script to attempt to update the server at each restart automatically. Set to $true with $unattended set to $false you will be prompted.
# If there's no updates pending usually completes in a minute depending on bandwidth.
$update_server_override = $true

$update_mods_override = $true

# Forcibly stops any ARMA processes running
$force_stop = $true

### Local files config
# This script will create the required folder structure, please just define where SteamCMD is and where you want the game server.

# Steamcmd path
$steamcmd_path = "C:\steamcmd\steamcmd.exe"

# Steam username, recommend making a separate Steam account with just ARMA on it.
$steam_u = "steam_username"

# Steam Password
$steam_p = "steam_password"

# The place you put everything game server related - ***No white spaces, steamCMD doesn't handle them.***
$server_home = "C:\Game_Servers"

# Will become the parent folder for this whole server
$instance = "instance_name"

# this folder will be inside the ARMA directory and will hold the config file and logs.
$profile_name = "profile_name"

### ARMA server config ###

# Its public name in the server browser
$server_name = "My ARMA Server"

# If you want the server to be passworded
$server_password = "password"

# Your admin password for the server
$admin_password = "admin_password"

# Int - must be a number, player count for the server.
$player_count = 20

# the name of the mission file you will use (you'll copy it to the mpmissions folder at the end of install). No special characters.
[string]$mission_filename = "missionname.mapname"

# Mission Difficulty, options are: Recruit, Regular, Veteran, Custom
$difficulty = "Regular"

# MOTD is added to the config file.
$motd = { 
    "Welcome to my game server",
    "Please find our Discord at URL"
}

# Address of the local adapter, open cmd and type ipconfig and use the IPv4 address
$ip = "0.0.0.0"

# Port you want the server to run on.
$port = "2302"

# CPUs to dedicate to the server
$cpu_count = 2

# MB of RAM the server should use
$max_mem = 4096

# Battleye enabled / disabled, 0 = disabled, 1 = enabled
$battleye = 0

# Persistence, will this server run all the time and keep the mission loaded? 0 = disabled, 1 = enabled
$persistent = 0

# Small mods under 1Gb, these will be downloaded all in one session from Steam.
# Place your mods in here inside quotes, comma separated, no comma at the end of the last entry.
$mods = @(
"463939057", # ace
"450814997", # CBA_A3
"333310405", # Enhanced Movement
"767380317", # BlastCore edited (standalone version)
"713709341", # Advanced Rappelling
"615007497", # Advanced Sling Loading
"639837898", # Advanced Towing
"730310357" # Advanced Urban Rappelling
)

# Large mods over 1Gb here, the script will download them individually, continually retrying and validating until completed. Certain mods like CUP can take 4-5 run throughs.
# Place your mods in here inside quotes, comma separated, no comma at the end of the last entry.
$large_mods = @(
"583496184", # CUP Terrains - Core
"583544987", # CUP Terrains - Maps
"497661914", # CUP Units
"541888371", # CUP Vehicles
"497660133" # CUP Weapons
)

 # Place your admins steamIDs in here inside quotes, comma separated, no comma at the end of the last entry.
$admins = @(
"steamID",
"steamID"
)
# Headless Client Config

$headless_client = $true

if ($headless_client -eq $true) {
    
    $headless_client_ips = @("127.0.0.1")
}
#######################################################################
#######################################################################
##### DO NOT CHANGE BELOW THIS POINT - UNLESS YOU KNOW POWERSHELL #####
#######################################################################
#######################################################################

# Forcibly closes all running ARMA servers. All servers instances need to be off for the update to be successful
if ($force_stop -eq $true) {
    Stop-Process -Name "Arma*" -Force
}

# Defines where the ARMA server files will be installed
$server_path = "$server_home\$instance\server_files"

# Communal location for all ARMA mods in this $server_home defined directory, to prevent doubling up when hosting more than one server.
$mods_path = "$server_home\arma3_mods"

# Checks the presence of the server home path
$test_server_home = Test-Path -Path $server_home

# Creates the server home path if it's missing
if ($test_server_home -eq $false) {
    New-Item -Path $server_home -ItemType Directory
}

# Checks the presence of the server files path
$test_server_path = Test-Path -Path $server_path

# Creates the server files path if it's missing
if ($test_server_path -eq $false) {
    New-Item -Path $server_path -ItemType Directory
}

# Creates the mods file path if it's mising
$test_mods_path = Test-Path -Path $mods_path

if ($test_mods_path -eq $false) {
    New-Item -Path $mods_path -ItemType Directory
}

# Checks for white space in the server path and throws an error if found
if ($server_path -match ' ') {
    [System.Windows.MessageBox]::Show('White space detected in server path, exiting.','Error','Ok','Error')
    break
}

# Defines the port range for the Windows firewall
$port_range = "$port"+"-"+(($port -as [int])+9)

# Adds the firewall rules to the Windows firewall
$tcpfirewall_status = Get-NetFirewallRule -DisplayName "$profile_name TCP" | Select-Object -ExpandProperty PrimaryStatus
if ($tcpfirewall_status -ne "OK") {
    New-NetFirewallRule -DisplayName "$profile_name TCP" -Direction Inbound -LocalPort $port_range -Protocol TCP -Action Allow
}

$udpfirewall_status = Get-NetFirewallRule -DisplayName "$profile_name UDP" | Select-Object -ExpandProperty PrimaryStatus
if ($udpfirewall_status -ne "OK") {
    New-NetFirewallRule -DisplayName "$profile_name UDP" -Direction Inbound -LocalPort $port_range -Protocol UDP -Action Allow
}

# If in attended mode and no credentials defined prompt the user for steam credentials
if ($unattended -eq $false) {
    Add-Type -AssemblyName System.Windows.Forms
    if ($steam_u -eq $null) {
        [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
        $title1 = 'Steam Username'
        $msg1   = 'Enter your Steam Username:'
        $steam_u = [Microsoft.VisualBasic.Interaction]::InputBox($msg1, $title1," ")
    }
    if ($steam_p -eq $null) {
        [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
        $title2 = 'Steam Password'
        $msg2   = 'Enter your Steam Password:'
        $steam_p = [Microsoft.VisualBasic.Interaction]::InputBox($msg2, $title2," ")
    }
    $steam_guard = [System.Windows.Forms.MessageBox]::Show("Do you use Steam Guard?","Steam Guard", "YesNo" , "Information" , "Button1")
}

# Steam ID for ARMA 3 dedicated server
$steam_gameid_dedi = "233780"

# Steam ID for ARMA 3 client
$steam_gameid_game = "107410"

if ($update_server_override -eq $true) {
    if ($unattended -eq $false) {
        $update_server = [System.Windows.Forms.MessageBox]::Show("Update ARMA Server?","ARMA Server", "YesNo" , "Information" , "Button1")
        if ($update_server -eq "Yes") {
            if ($steam_guard -eq "Yes") {
                [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
                $title3 = 'Steam Guard'
                $msg3   = 'Enter your Steam Guard Token:'
                $steam_g = [Microsoft.VisualBasic.Interaction]::InputBox($msg3, $title3," ")
                Start-Process -FilePath $steamcmd_path ('+login',$steam_u,$steam_p,$steam_g,'+force_install_dir',"$server_path",'+app_update',$steam_gameid_dedi,'validate', '+quit') -Wait
            } else {
                Start-Process -FilePath $steamcmd_path ('+login',$steam_u,$steam_p,'+force_install_dir',"$server_path",'+app_update',$steam_gameid_dedi,'validate', '+quit') -Wait
            }
        }
    } else {
        Start-Process -FilePath $steamcmd_path ('+login',$steam_u,$steam_p,'+force_install_dir',"$server_path",'+app_update',$steam_gameid_dedi,'validate', '+quit') -Wait
    }
}

# Will step through the mods and download them with steamCMD. Large mods will be downloaded one at a time, will continue to loop until all mods are downloaded, large mods can take several attempts.
if ($update_mods_override -eq $true) {
    if ($unattended -eq $false) {
        $update_mods = [System.Windows.Forms.MessageBox]::Show("Update ARMA Mods?","ARMA Mods", "YesNo" , "Information" , "Button1")
        if ($update_mods -eq "Yes") {
        $keys = Get-ChildItem -Path "$server_path\keys" | Where {$_.Name -ne "a3.bikey"}
        $keys | Remove-Item -Recurse -Force
            if ($steam_guard -eq "Yes") {
                [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
                $title3 = 'Steam Guard'
                $msg3   = 'Enter your Steam Guard Token:'
                $steam_g = [Microsoft.VisualBasic.Interaction]::InputBox($msg3, $title3," ")
                $steam_mod_arguments = @('+login',$steam_u,$steam_p,$steam_g,'+force_install_dir',$mods_path)
            } else {
                $steam_mod_arguments = @('+login',$steam_u,$steam_p,'+force_install_dir',$mods_path)
            }
            foreach ($mod in $mods) {
                $steam_mod_arguments += "+workshop_download_item"
                $steam_mod_arguments += $steam_gameid_game
                $steam_mod_arguments += $mod
            }
            $steam_mod_arguments += 'validate'
            $steam_mod_arguments += '+quit'

            Start-Process -FilePath $steamcmd_path $steam_mod_arguments -Wait

            foreach ($mod in $large_mods) {
                if ($steam_guard -eq "Yes") {
                    do {
                        [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
                        $title3 = 'Steam Guard'
                        $msg3   = 'Enter your Steam Guard Token:'
                        $steam_g = [Microsoft.VisualBasic.Interaction]::InputBox($msg3, $title3," ")
                        $steam_mod_arguments = @('+login',$steam_u,$steam_p,$steam_g,'+force_install_dir',$mods_path)
                        $steam_mod_arguments += "+workshop_download_item"
                        $steam_mod_arguments += $steam_gameid_game
                        $steam_mod_arguments += $mod
                        $steam_mod_arguments += 'validate'
                        $steam_mod_arguments += '+quit'
                        Start-Process -FilePath $steamcmd_path $steam_mod_arguments -Wait
                        Write-Host "Sleeping for 10 seconds to help prevent Steam lockout" -ForegroundColor Red
                        Start-Sleep -Seconds 10
                    } until ((Test-Path "$mods_path\steamapps\workshop\downloads\$steam_gameid_game\*") -ne $true)
                } else {
                    $steam_mod_arguments = @('+login',$steam_u,$steam_p,'+force_install_dir',$mods_path)
                    $steam_mod_arguments += "+workshop_download_item"
                    $steam_mod_arguments += $steam_gameid_game
                    $steam_mod_arguments += $mod
                    $steam_mod_arguments += 'validate'
                    $steam_mod_arguments += '+quit'
                    do {
                        Start-Process -FilePath $steamcmd_path $steam_mod_arguments -Wait
                        Write-Host "Sleeping for 10 seconds to help prevent Steam lockout" -ForegroundColor Red
                        Start-Sleep -Seconds 10
                    } until ((Test-Path "$mods_path\steamapps\workshop\downloads\$steam_gameid_game\*") -ne $true)
                }
            }

            $mods += $large_mods

            foreach ($mod in $mods) {
                $source_mod_path = "$mods_path\steamapps\workshop\content\107410\$mod"
                $mod_name = get-content "$source_mod_path\meta.cpp" | Select-String -SimpleMatch name
                $mod_name = $mod_name.ToString()
                $mod_name = $mod_name|%{$_.split('"')[1]}
                $mod_name = $mod_name -replace '[\W]', ''
                $mod_name = "@"+$mod_name
                $sym_link_path = "$server_path\$mod_name"
                $path_test = Test-Path $sym_link_path
                if ($path_test -eq $false) {
                    New-Item -ItemType SymbolicLink -Path $sym_link_path -Target $source_mod_path
                }
                Copy-Item "$sym_link_path\*key*\*.bikey" "$server_path\keys"
            }
        }
    } else {
        $steam_mod_arguments = @('+login',$steam_u,$steam_p,'+force_install_dir',$mods_path)
        foreach ($mod in $mods) {
            $steam_mod_arguments += "+workshop_download_item"
            $steam_mod_arguments += $steam_gameid_game
            $steam_mod_arguments += $mod
        }
        $steam_mod_arguments += 'validate'
        $steam_mod_arguments += '+quit'
        Start-Process -FilePath $steamcmd_path $steam_mod_arguments -Wait

        foreach ($mod in $large_mods) {
            $steam_mod_arguments = @('+login',$steam_u,$steam_p,'+force_install_dir',$mods_path)
            $steam_mod_arguments += "+workshop_download_item"
            $steam_mod_arguments += $steam_gameid_game
            $steam_mod_arguments += $mod
            $steam_mod_arguments += 'validate'
            $steam_mod_arguments += '+quit'
            do {
                Start-Process -FilePath $steamcmd_path $steam_mod_arguments -Wait
                Write-Host "Sleeping for 10 seconds to help prevent Steam lockout" -ForegroundColor Red
                Start-Sleep -Seconds 10
            } until ((Test-Path "$mods_path\steamapps\workshop\downloads\$steam_gameid_game\*") -ne $true)
        }
    }

    $mods += $large_mods

    foreach ($mod in $mods) {
        $source_mod_path = "$mods_path\steamapps\workshop\content\107410\$mod"
        $mod_name = get-content "$source_mod_path\meta.cpp" | Select-String -SimpleMatch name
        $mod_name = $mod_name.ToString()
        $mod_name = $mod_name|%{$_.split('"')[1]}
        $mod_name = $mod_name -replace '[\W]', ''
        $mod_name = "@"+$mod_name
        $sym_link_path = "$server_path\$mod_name"
        $path_test = Test-Path $sym_link_path
        if ($path_test -eq $false) {
            New-Item -ItemType SymbolicLink -Path $sym_link_path -Target $source_mod_path
        }
        Copy-Item "$sym_link_path\*key*\*.bikey" "$server_path\keys"
    }
}


$steamcmd_downloads = Get-ChildItem "$mods_path\steamapps\workshop\downloads\$steam_gameid_game"

if ($unattended -eq $false) {
    if ($steamcmd_downloads -ne $null) {
        [System.Windows.MessageBox]::Show("Mods failed to fully download, check $mods_path\steamapps\workshop\downloads\$steam_gameid_game for failing mods, exiting.",'Error','Ok','Error')
        break
    }
}

Clear-Variable steam_mod_arguments

$profile_path = "$server_path\$profile_name"

$test_profile_path = Test-Path -Path $profile_path

if ($test_profile_path -eq $false) {
    New-Item -Path $profile_path -ItemType Directory
}

$server_exe = "$server_path\arma3server_x64.exe"

$mod_folders = Get-ChildItem -Path "$server_path" -Name "@*"

$basic_name = $profile_name+"_basic.cfg"

$basic_path = "$profile_path\$basic_name"

$config_name = $profile_name+"_config.cfg"

$config_path = "$profile_path\$config_name"

$be_path = "$server_path\$profile_name\battleye"

$basic_file_contents = @"
// These options are created by default
language="English";
adapter=-1;
3D_Performance=1.000000;
Resolution_W=800;
Resolution_H=600;
Resolution_Bpp=32;


// These options are important for performance tuning

MinBandwidth = 131072;			// Bandwidth the server is guaranteed to have (in bps). This value helps server to estimate bandwidth available. Increasing it to too optimistic values can increase lag and CPU load, as too many messages will be sent but discarded. Default: 131072
MaxBandwidth = 10000000000;		// Bandwidth the server is guaranteed to never have. This value helps the server to estimate bandwidth available.

MaxMsgSend = 128;			// Maximum number of messages that can be sent in one simulation cycle. Increasing this value can decrease lag on high upload bandwidth servers. Default: 128
MaxSizeGuaranteed = 512;		// Maximum size of guaranteed packet in bytes (without headers). Small messages are packed to larger frames. Guaranteed messages are used for non-repetitive events like shooting. Default: 512
MaxSizeNonguaranteed = 256;		// Maximum size of non-guaranteed packet in bytes (without headers). Non-guaranteed messages are used for repetitive updates like soldier or vehicle position. Increasing this value may improve bandwidth requirement, but it may increase lag. Default: 256

MinErrorToSend = 0.001;			// Minimal error to send updates across network. Using a smaller value can make units observed by binoculars or sniper rifle to move smoother. Default: 0.001
MinErrorToSendNear = 0.01;		// Minimal error to send updates across network for near units. Using larger value can reduce traffic sent for near units. Used to control client to server traffic as well. Default: 0.01

MaxCustomFileSize = 0;			// (bytes) Users with custom face or custom sound larger than this size are kicked when trying to connect.
"@

Set-Content -Path $basic_path -Value $basic_file_contents

$mission_class = ($mission_filename.Split('.'))[0]

if ($mission_class -like "*liberation*") {
    $params = @"
    class Params
			{
				Unitcap = 1;                      // Maximum amount AI units - [default 1] - values = [0.5,0.75,1,1.25,1.5,2] - Text {50%,%75,%100,%125,%150,%200}
				Difficulty = 0.5;                   // Difficulty - [default 1] - values = [0.5,0.75,1,1.25,1.5,2,4,10] - Text {Tourist,Easy,Normal,Moderate,Hard,Extreme,Ludicrous,Oh god oh god we are all going to die}
				Aggressivity = 1;                 // CSAT aggression - [default 1] - values = [0.25,0.5,1,2,4] - Text {Anemic,Weak,Normal,Strong,Extreme}
				AdaptiveEnemy = 1;           // Hostile presence adapts to player count - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				DayDuration = 12;                 // Day duration (hours) - [default 12] - values = [48,24,16,12,9.6,8,6.8,6,4.8,4,3,2.4,2,1.6,1,0.66,0.5,0.375,0.25,0.1875,0.125,0.11] - Text {0.5,1,1.5,2,2.5,3,3.5,4,5,6,8,10,12,15,24,36,48,64,96,128}
				ShortNight = 1;                // Shorter nights - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				Weather = 3;                      // Weather - [default 3] - values = [1,2,3] - Text {Always Sunny,Random without rain,Random}
				ResourcesMultiplier = 1;          // Resource multiplier - [default 1] - values = [0.25,0.5,0.75,1,1.25,1.5,2,3,5,10,20,50] - Text {x0.25,x0.5,x1,x1.25,x1.5,x2,x3,x5,x10,x20,x50}
				Fatigue = 1;                      // Stamina - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				ReviveMode = 1;
				ReviveRequiredItems = 2;          // FAR revive - [default 3] - values = [3,2,1,0] - Text {Enabled - Everyone can revive using medkit,Enabled - Everyone can revive using FAK,Enabled - Only medics can revive,Disabled}
				ReviveRequiredTrait = 0;
				ReviveBleedOutDuration = 300;
				CleanupVeh = 0;
				MobileRespawn = 1;
				RespawnCd = 0;
				Civilians = 2;                    // Cilivilian activity - [default 1] - values = [0,0.5,1,2] - Text {None,Reduced,Normal,Increased}
				TeamkillPenalty = 1;              // Teamkill Penalty - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				PassiveIncome = 0;                // Replace ammo box spawns with passive income - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				AmmoBounties = 1;                 // Ammunition bounties - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				HaloJump = 1;                     // HALO jump - [default 1] - values = [1,5,10,15,20,30,0] - Text {Enabled - no cooldown,Enabled - 5min cooldown,Enabled - 10min cooldown,Enabled - 15min cooldown,Enabled - 20min cooldown,Enabled - 30min cooldown,Disabled}
				BluforDefenders = 1;              // BLUFOR defenders in owned sectors - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				Autodanger = 1;                   // Auto-Danger behaviour on BLUFOR forces - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				MaximumFobs = 26;                 // Maximum number of FOBs allowed - [default 26] - values = [3,5,7,10,15,20,26] - Text {3,5,7,10,15,20,26}
				Permissions = 1;                  // Permissions management - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				CleanupVehicles = 0;              // Cleanup abandoned vehicles outside FOBs - [default 2] - values = [0,1,2,4] - Text {Disabled,Enabled - 1 hour delay,Enabled - 2 hour delay,Enabled - 4 hour delay,}
				Introduction = 1;                 // Introduction - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				DeploymentCinematic = 0;          // Deployment cimematic - [default 1] - values = [1,0] - Text {Enabled,Disabled}
				FirstFob = 0;                     // Start campaign with the first FOB prebuilt - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				Whitelist = 0;                    // Use the commander whilelist - [default 0] - values = [1,0] - Text {Enabled,Disabled}
				WipeSave1 = 0;                    // Wipe Savegame - [default 0] - values = [0,1] - Text {No, Savegame will be wiped no recovery possible}
				WipeSave2 = 0;                    // Confirm: Wipe Savegame - [default 0] - values = [0,1] - Text {No, Savegame will be wiped no recovery possible}
				DisableRemoteSensors = 0;         // Disable remote sensors (experimental!) - [default 0] - values = [0,1,2] - Text {No,Disabled for clients without local AI,Disabled for all clients}
				MaxSquadSize = 50;
				AiDefenders = 1;
        };
"@
}

$config_file_contents = @"
//
// server.cfg
//
// comments are written with "//" in front of them.

// GLOBAL SETTINGS
hostname = "$server_name";		// The name of the server that shall be displayed in the public server list
password = "$server_password";					// Password for joining, eg connecting to the server
passwordAdmin = "$admin_password";				// Password to become server admin. When you're in Arma MP and connected to the server, type '#login xyz'
serverCommandPassword = "xyzxyz";               // Password required by alternate syntax of [[serverCommand]] server-side scripting.
upnp = true;

//reportingIP = "armedass.master.gamespy.com";	// For ArmA1 publicly list your server on GameSpy. Leave empty for private servers
//reportingIP = "arma2pc.master.gamespy.com";	// For ArmA2 publicly list your server on GameSpy. Leave empty for private servers
//reportingIP = "arma2oapc.master.gamespy.com";	// For Arma2: Operation Arrowhead  //this option is deprecated since A2: OA version 1.63
//reportingIP = "arma3" //not used at all
logFile = "server_console.log";			// Tells ArmA-server where the logfile should go and what it should be called

// WELCOME MESSAGE ("message of the day")
// It can be several lines, separated by comma
// Empty messages "" will not be displayed at all but are only for increasing the interval
motd[] = {
	"", "",  
	$motd
};
motdInterval = 5;				// Time interval (in seconds) between each message

// JOINING RULES
//checkfiles[] = {};				// Outdated.
maxPlayers = $player_count;				// Maximum amount of players. Civilians and watchers, beholder, bystanders and so on also count as player.
kickDuplicate = 1;				// Each ArmA version has its own ID. If kickDuplicate is set to 1, a player will be kicked when he joins a server where another player with the same ID is playing.
verifySignatures = 2;				// Verifies .pbos against .bisign files. Valid values 0 (disabled), 1 (prefer v2 sigs but accept v1 too) and 2 (only v2 sigs are allowed). 
equalModRequired = 0;				// Outdated. If set to 1, player has to use exactly the same -mod= startup parameter as the server.
allowedFilePatching = 0;                        // Allow or prevent client using -filePatching to join the server. 0, is disallow, 1 is allow HC, 2 is allow all clients (since Arma 3 1.49+)
filePatchingExceptions[] = {"123456789","987654321"}; // Whitelisted Steam IDs allowed to join with -filePatching enabled 
//requiredBuild = 12345				// Require clients joining to have at least build 12345 of game, preventing obsolete clients to connect

// VOTING
voteMissionPlayers = 1;				// Tells the server how many people must connect so that it displays the mission selection screen.
voteThreshold = 0.99;				// 33% or more players need to vote for something, for example an admin or a new map, to become effective
allowedVoteCmds[] =            // Voting commands allowed to players
{
	// {command, preinit, postinit, threshold} - specifying a threshold value will override "voteThreshold" for that command
	{"admin", false, false}, // vote admin
	{"kick", false, true, 0.51}, // vote kick
	{"missions", true, true, 0.51}, // mission change
	{"mission", true, true,0.51}, // mission selection
	{"restart", false, false, 0.51}, // mission restart
	{"reassign", false, false, 0.51} // mission restart with roles unassigned

// INGAME SETTINGS
disableVoN = 0;					// If set to 1, Voice over Net will not be available
vonCodec = 1; 					// If set to 1 then it uses IETF standard OPUS codec, if to 0 then it uses SPEEX codec (since Arma 3 update 1.58+)  
vonCodecQuality = 30;				// since 1.62.95417 supports range 1-20 //since 1.63.x will supports range 1-30 //8kHz is 0-10, 16kHz is 11-20, 32kHz(48kHz) is 21-30 
persistent = $persistent;					// If 1, missions still run on even after the last player disconnected.
timeStampFormat = "short";			// Set the timestamp format used on each report line in server-side RPT file. Possible values are "none" (default),"short","full".
BattlEye = $battleye;					// Server to use BattlEye system
allowedLoadFileExtensions[] = {"hpp","sqs","sqf","fsm","cpp","paa","txt","xml","inc","ext","sqm","ods","fxy","lip","csv","kb","bik","bikb","html","htm","biedi"}; //only allow files with those extensions to be loaded via loadFile command (since Arma 3 build 1.19.124216)
allowedPreprocessFileExtensions[] = {"hpp","sqs","sqf","fsm","cpp","paa","txt","xml","inc","ext","sqm","ods","fxy","lip","csv","kb","bik","bikb","html","htm","biedi"}; //only allow files with those extensions to be loaded via preprocessFile/preprocessFileLineNumber commands (since Arma 3 build 1.19.124323)
allowedHTMLLoadExtensions[] = {"htm","html","xml","txt"}; //only allow files with those extensions to be loaded via HTMLLoad command (since Arma 3 build 1.27.126715)
//allowedHTMLLoadURIs[] = {}; // Leave commented to let missions/campaigns/addons decide what URIs are supported. Uncomment to define server-level restrictions for URIs

// TIMEOUTS
disconnectTimeout = 5; // Time to wait before disconnecting a user which temporarly lost connection. Range is 5 to 90 seconds.
maxDesync = 150; // Max desync value until server kick the user
maxPing= 300; // Max ping value until server kick the user
maxPacketLoss= 50; // Max packetloss value until server kick the user
kickClientsOnSlowNetwork[] = { 0, 0, 0, 0 }; //Defines if {<MaxPing>, <MaxPacketLoss>, <MaxDesync>, <DisconnectTimeout>} will be logged (0) or kicked (1)
kickTimeout[] = { {0, -1}, {1, 180}, {2, 180}, {3, 180} };
votingTimeOut[] = {0, -1}; // Kicks users from server if they spend too much time in mission voting
roleTimeOut[] = {0, -1}; // Kicks users from server if they spend too much time in role selection 
briefingTimeOut[] = {0, -1}; // Kicks users from server if they spend too much time in briefing (map) screen
debriefingTimeOut[] = {0, -1}; // Kicks users from server if they spend too much time in debriefing screen
lobbyIdleTimeout = 300; // The amount of time the server will wait before force-starting a mission without a logged-in Admin.

// SCRIPTING ISSUES
onUserConnected = "";				//
onUserDisconnected = "";			//
doubleIdDetected = "";				//
//regularCheck = "{}";				//  Server checks files from time to time by hashing them and comparing the hash to the hash values of the clients. //deprecated

// SIGNATURE VERIFICATION
onUnsignedData = "kick (_this select 0)";	// unsigned data detected
onHackedData = "kick (_this select 0)";		// tampering of the signature detected
onDifferentData = "";				// data with a valid signature, but different version than the one present on server detected

// MISSIONS CYCLE (see below)
randomMissionOrder = false; // Randomly iterate through Missions list
autoSelectMission = false; // Server auto selects next mission in cycle

class Missions {
    class $mission_class {
        template = "$mission_filename";
        difficulty = "regular";
        $params
    };				// An empty Missions class means there will be no mission rotation
};

missionWhitelist[] = {}; // An empty whitelist means there is no restriction on what missions' available
admins[] = {$admins};
headlessClients[] = {$headless_client_ips};
"@

Set-Content -Path $config_path -Value $config_file_contents
 
# Start server

foreach ($mod in $mod_folders) {
    if ($mod -notmatch "Server") {
        $mod_list +="$mod;"
    } else {
        $mod = "$server_path\$mod"
        $server_mod_list +="$mod;"
    }
}

if ($persistent -eq 0) {
    $arguments_list = "-ip=$ip -port=$port -noPause -noSound -cpuCount=$cpu_count -maxMem=$max_mem -profiles=$profile_path -bepath=$be_path -cfg=$basic_path -config=$config_path -mod=$mod_list -serverMod=$server_mod_list"
} else {
    $arguments_list = "-ip=$ip -port=$port -noPause -noSound -autoinit -cpuCount=$cpu_count -maxMem=$max_mem -profiles=$profile_path -bepath=$be_path -cfg=$basic_path -config=$config_path -mod=$mod_list -serverMod=$server_mod_list"
}

if ($unattended -eq $false) {
    $test_mission_file = Test-Path -Path "$server_path\mpmissions\$mission_filename.pbo"
    if ($test_mission_file -eq $false) {
         [System.Windows.MessageBox]::Show("$mission_filename Missing. Exiting.")
         $date = Get-Date -Format yyyyMMdd_HHmmss
         Add-Content -Path "$profile_path\powershell_error_log_$date.txt" -Value "$mission_filename Missing from $server_path\mpmissions"
         Break
    } else {
        $run_server = [System.Windows.Forms.MessageBox]::Show("Run ARMA Server $instance ?","Run Server", "YesNo" , "Information" , "Button1")
        if ($run_server -eq "Yes") {
			if ($headless_client -eq $true) {
                if ($server_password -ne $null) {
                    $hc_args = "-client -connect=$ip -mods=$mod_list -password=$server_password"
                } else {
                    $hc_args = "-client -connect=$ip -mods=$mod_list"
                }
                Start-Process -FilePath $server_exe -ArgumentList ($hc_args)
            }
            Start-Sleep -Seconds 5
            Start-Process -FilePath $server_exe -ArgumentList ($arguments_list)
            $mod_list
        }
    }
} else {
	if ($headless_client -eq $true) {
        if ($server_password -ne $null) {
            $hc_args = "-client -connect=$ip -mods=$mod_list -password=$server_password"
        } else {
            $hc_args = "-client -connect=$ip -mods=$mod_list"
        }
        Start-Process -FilePath $server_exe -ArgumentList ($hc_args)
    }
    Start-Sleep -Seconds 5
    Start-Process -FilePath $server_exe -ArgumentList ($arguments_list)
}

Clear-Variable mod_list