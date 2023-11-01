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
Add to your `config/prod.secret.exs` the following block.

```
config :teiserver, DiscordBridgeBot,
  token: "TOKEN",
  bot_name: "BOT NAME",
  bridges: [
    {"Channel", "Room"}
  ]
```

- token: The bot token found the Discord application for the bot in the bot tab
- bot_name: The display name of the bot, if you don't have this correct the bot can respond to it's own messages creating an infinite loop
- bridges: A list of tuple pairs of the channels/rooms you are linking

To get a channel ID in your discord settings enable developer mode in advanced settings. Then right click the channel you wish to bridge to and select `Copy ID`. Paste that ID into the first element of the tuple and replace the second element with the room you wish to bridge to.

Finally you need to enable the bot in either `config/prod.secret.exs` or `config/prod.exs`.

```
config :teiserver, Teiserver,
  enable_discord_bridge: true
```

### Moderator actions
If one of the bridge channels is called "moderation-reports" then it will not bridge the normal way and instead be used for bridging user reports.
If one of the bridge channels is called "moderation-actions" then it will not bridge the normal way and instead be used for bridging moderator actions (including warnings).

### Developing the bot
If you are working on the bot in development then you'll need to create a 2nd bot account as above and link it to the relevant place for testing. Place the same config structure in `config/dev.secret.exs`, enable it and you should be good to go!
