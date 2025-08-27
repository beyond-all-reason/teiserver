## Creating your bot and adding it to your server
1. Go to https://discord.com/developers/applications/ and create a new application
2. Pick a name for the application
3. Go to Bot tab
4. Click reset token to get the access token, copy it, you will need it later for configuration
5. Make sure “Message Content Intent” is enabled
6. Go to OAuth2 tab
7. In OAuth2 URL Generator select the following:
  - Scopes: `bot`, `application.commands`
  - Bot Permissions: `Administrator`
8. Select Integration type Guild install
9. Copy and open the generated URL to add the bot to your server

### Bot configuration
You need to set the following environment variables:
```
TEI_ENABLE_DISCORD_BRIDGE=true
TEI_DISCORD_BOT_TOKEN={{ TOKEN }}
TEI_DISCORD_GUILD_ID=xxx
TEI_DISCORD_BOT_NAME=test-teiserver-self-server
```

- TOKEN: The bot token generated while creating the bot
- GUILD_ID: Server ID
- BOT_NAME: The display name of the bot, if you don't have this correct the bot can respond to it's own messages creating an infinite loop

> The easiest way to get Discord server, channel, message or user IDs is by enabling developer mode in Discord's advanced settigns. Right click the server, channel, message or user you wish to copy the ID from and select `Copy ID`. Check [this discord article](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID) for details.

### Server startup
You can test if the bot is working by using a commands like `$unit corjugg`.

The easiest way to test that the bridge is working is to look for the startup message in Discord.
Get the [channel id](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID#h_01HRSTXPS5FMK2A5SMVSX4JW4E) and set it as a db setting through the web UI
1. Go to [Discord site config](http://localhost:4000/teiserver/admin/site#Discord)
2. Fill the channel ID under `#server-updates`
3. When starting the server with `mix phx.server`, you should get a message from the bot in that channel.

### Moderator actions
If one of the bridge channels is called "moderation-reports" then it will not bridge the normal way and instead be used for bridging user reports.
If one of the bridge channels is called "moderation-actions" then it will not bridge the normal way and instead be used for bridging moderator actions (including warnings).

### Developing the bot
If you are working on the bot in development then you'll need to create a 2nd bot account as above and link it to the relevant place for testing.
