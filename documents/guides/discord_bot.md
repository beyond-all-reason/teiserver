## Creating your bot
- Go to https://discord.com/developers/applications/ and create a new application.
- Pick a name for the application
- Give it an icon
- Go to the bot option and enable it as a bot

### Adding it to your server
Still in the discord application page
- Go to OAuth2 tab
- Copy ClientID
- Put it into this url

> https://discord.com/oauth2/authorize?scope=bot+applications.commands&client_id=**client_id**

Go to that URL and follow the steps to add your bot to the server of your choosing. If you get a grant or token related error ensure in the Bot tab that "Requires Oauth2 code grant" is set to off.

Congratulations, your bot is set up!

### Configuring it to bridge

You need to set the following environment variables:

```
TEI_ENABLE_DISCORD_BRIDGE=true
TEI_DISCORD_BOT_TOKEN={{ TOKEN }}
TEI_DISCORD_GUILD_ID=xxx
TEI_DISCORD_BOT_NAME=test-teiserver-self-server
TEI_DISCORD_BOT_EMAIL=test-teiserver-self-server@teiserver
```

- TOKEN: The bot token found the Discord application for the bot in the bot tab
- GUILD_ID: this is the server ID, see [this discord article](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID) to see how to get it.
- bot_name: The display name of the bot, if you don't have this correct the bot can respond to it's own messages creating an infinite loop

To get a channel ID in your discord settings enable developer mode in advanced settings. Then right click the channel you wish to bridge to and select `Copy ID`. Paste that ID into the first element of the tuple and replace the second element with the room you wish to bridge to.

### Server startup
The easiest way to test the bridge is working is to look for the startup message in discord. Get the [channel id](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID#h_01HRSTXPS5FMK2A5SMVSX4JW4E) and set it as a db settings through the web ui:
* go under [the web ui](http://localhost:4000/teiserver/admin/site#Discord)
* fill the channel id under `#server-updates`
* when starting the server with `mix phx.server`, you should get a message from the bot in that channel.

### Moderator actions
If one of the bridge channels is called "moderation-reports" then it will not bridge the normal way and instead be used for bridging user reports.
If one of the bridge channels is called "moderation-actions" then it will not bridge the normal way and instead be used for bridging moderator actions (including warnings).

### Developing the bot
If you are working on the bot in development then you'll need to create a 2nd bot account as above and link it to the relevant place for testing.
