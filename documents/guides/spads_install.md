# SPADS setup
[SPADS]((https://github.com/Yaribz/SPADS)) (Spring Perl Autohost for Dedicated Server) is a Perl autohost program for SpringRTS/Recoil engine. You should set it up if you wish to develop and test features related to lobbies over the Spring protocol.

## Purpose of SPADS installation
If you run your local Teiserver, you can connect to it through a client like Chobby by changing the server address to `localhost` and logging in. However, there won't see any lobbies. Lobbies are hosted and managed by SPADS so you will need to set it up first if you wish to work with them.

## SPADS installation
There are several ways to install SPADS, but the recommended method when using Teiserver and Beyond All Reason is to follow the local testing instructions in the [Ansible SPADS Setup](https://github.com/beyond-all-reason/ansible-spads-setup?tab=readme-ov-file#local-testing). This Ansible playbook is up to date and used for production setups. It automates most of the installation and setup process and is significantly faster than doing it manually.


> [!IMPORTANT]
> The recommended way to set up SPADS is with the Ansible playbook. The section below is here just in case you don't want to use Ansible.


## Create a bot account to be used by SPADS
Run Teiserver locally, login as root@localhost and go to 
http://localhost:4000/teiserver/admin/user

Search for a user that has FakeData as the client (i.e. a normal user). Then Edit User > Tick "Bot" and "Verified" > Save Changes

The SPADS bot must have a name with **20 or less characters**. If you wish to rename the user, remove `edit` from the url, e.g.
```
http://localhost:4000/teiserver/admin/user/{id}
```
Select Actions > Rename.

Note this username as it will be used later. 

## Point Chobby to local Teiserver
Inside your install folder for Beyond All Reason, add a `devmode.txt` file. This will make dev settings available in BAR.
1. Start Beyond All Reason
2. Go to Settings
3. Scroll down to the bottom
4. Change the `Server Address` option to `localhost`

Go to Multiplayer & Coop and Login as the bot user you created earlier.
All these fake users created by the fake data script should have a password of `password`
Accept any agreement if needed. This is just to test if everything works. You can now Exit the app.

## Install SPADS Prerequisites
Download dependencies by following the prerequisite instructions [here](https://github.com/Yaribz/SPADS/blob/master/INSTALL.md). In theory if you have Teiserver on Windows through WSL, you could use either the Linux or Windows prerequisite instructions.

Another dependency we need that is not listed is Inline::Python. This dependency is used by one of BAR's plugins. [Here is the install documentation.](https://github.com/Yaribz/SPADS/wiki/SPADS-Inline::Python-installation-guide)

## Install SPADS
Further down the previous page are [install instructions](https://github.com/Yaribz/SPADS/blob/master/INSTALL.md#installation-instructions) for SPADS. Follow only steps 1 and 2 of the Installation instructions. When downloading spadsInstaller.tar it might be flagged because the file is hosted on http instead of https.

Now for the third setp run this instead on your SPADS folder:
```bash
perl spadsInstaller.pl --auto BarMinimalMaps
```
This will install SPADS with some BAR-specific configurations. It will ask some questions and most will be answered automatically. Step 8 may take a while as it downloads BAR. Near the end, it will ask you for a username/password for SPADS to use. Use the bot user you created earlier. Remember all users have password of `password`.

> [!NOTE]
> If you need to change the username/password at a later point, you can do so inside `etc/spads.conf`

Finally it will ask you for another login for autohost owner. You can enter anything here, even a user that doesn't exist. It's not used.

## Config changes

Inside your SPADS folder, open etc/spads.config and change the lobbyHost field to point to our local TeiServer
```
lobbyHost:127.0.0.1
```

<details>
  <summary>If Beyond All Reason is installed on Windows and SPADS is in WSL, then open these instructions
</summary>
  
Change the IP address of `lobbyHost` to your WSL IP address (instead of 127.0.0.1). You can find your WSL IP address by running in command line:
```
wsl hostname -I
```

  
</details>


## Install SPADS Plugins
In your SPADS folder, open `etc/spads.conf`. Change the autoLoadPlugins line to this:
```
autoLoadPlugins:BarAutoUpdate;BarManager;RatingManager
```
Enter this exactly the same as it is case sensitive.

Now we need to get BarManager and RatingManager plugins. Download the [spads_config_bar repo](https://github.com/beyond-all-reason/spads_config_bar). You can ignore the repo's readme because we only need a couple files from it.

Copy from the repo these files:
`etc/BarManager.conf`
`etc/BarManagerCmd.conf`
and paste into your SPADS etc folder.

Copy from the repo these files:
`var/plugins/BarManagerHelp.dat`
`var/plugins/barmanager.py`
`var/plugins/ratingmanager.py`
and paste into your SPADS var/plugins folder

We need to point our `var/plugins/ratingmanager.py` plugin to TeiServer so open it and set this line
```
server_url = "http://127.0.0.1:4000"
```

## Run SPADS
```
perl spads.pl etc/spads.conf
```

The first time you do this it will ask you to run it again with a parameter to trust the certificate. The [certificate](https://github.com/beyond-all-reason/teiserver/blob/master/documents/guides/local_setup.md#localhost-certs) is something you would have created when installing TeiServer.

## Launch the lobby
Run Beyond All Reason exe. Login as a user (but not the SPADS bot). You can go back to TeiServer to see the list of users. Use `password` as the password. If all is well, you should be able to see a battle room when you login to multiplayer.

## Potential Errors

### Geo IP Errors when you start a match
You may get an error to do with geoip when you start a match. In that case, go to [localhost:4000](http://localhost:4000)
Admin > Site Config > System
Then change "Use geoip" to false. Restart Teiserver. Now try and start a match again and it should work.
