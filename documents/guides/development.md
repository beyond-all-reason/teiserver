# Development
After finishing the local setup you are ready to start developing Teiserver.
This guide should hopefully help you with getting started by showing you some helpful commands and giving you a short introduction to different Teiserver components.

## Useful tools and commands
### Fake data

You will probably want some testing data (users, matches etc.) to make development and testing easier.

Running the following command will generate a large amount of fake data and setup a root account for you:
```bash
mix teiserver.fakedata
```
The database will be populated with false data as if generated over a period of time and the root account will have full access to everything.

> [!NOTE]
> Fake data is not perfect and might not be sufficient for your needs. You can modify and expand it by editing the [fakedata mix task](/lib/teiserver/mix_tasks/fake_data.ex) that generates it.


### Resetting your user password
When running locally it's likely you won't want to connect the server to an email account, as such password resets need to be done a little differently.

Run your server with `iex -S mix phx.server` and then once it has started up use the following code to update your password.

```elixir
user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")
Teiserver.Account.update_user(user, %{"password" => "password"})
```

### Ignore large `mix format` passes in `git blame`
In https://github.com/beyond-all-reason/teiserver/pull/304 we've started requiring compliance with `mix format` - this meant we had to use that on the entire codebase.

This obviously breaks `git blame`, but you can sidestep that by using
```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

The attached `.git-blame-ignore-revs` file contains a list of commit hashes which modify a large number of lines with trivial changes.

> [!NOTE]
> See [this blog post by Stefan Judis](https://www.stefanjudis.com/today-i-learned/how-to-exclude-commits-from-git-blame/) for reference.


### Git hooks
The `.githooks` directory contains a `pre-commit` Git hook that will run `mix format` on staged files before they get commited.
To use this (and other Git hooks) you have to first make them executable with
```bash
chmod +x .githooks/pre-commit
```
then use the following command to change the location where Git looks for hook scripts (from the default `.git/hooks`) to the `.githooks` directory
```bash
git config core.hooksPath .githooks
```

## Working on Teiserver
Teiserver handles a lot: account creation and management, user ratings, balancing, moderation, Discord bot, microblogs, chat, telemetry and more with the introduction of Tachyon.

This section is intended as a short overview of the main Teiserver components.

### Tachyon protocol
[Tachyon](https://github.com/beyond-all-reason/tachyon) is the new protocol under development, designed to replace the old Spring Lobby Protocol.
Check [this](https://beyond-all-reason.github.io/infrastructure/new_client/) for a wider overview. In short:
- The new client is [BAR lobby](https://github.com/beyond-all-reason/bar-lobby), it'll replace the existing [Chobby](https://github.com/beyond-all-reason/BYAR-Chobby) client
- The new autohost starting games is [Recoil autohost](https://github.com/beyond-all-reason/recoil-autohost) and will more or less replace SPADS, although a lot of what SPADS is currently doing will be done in Teiserver
- Teiserver is still the same, although the Tachyon related code is isolated from the Spring one

For developping Tachyon, you should also run
```bash
mix teiserver.tachyon_setup
```
This setup the OAuth applications required for Tachyon.

There is also
```bash
mix teiserver.gen_token --user CheerfulBeigeKarganeth --app generic_lobby
```
which generates an access token valid for 24h. These help a lot when attempting to manually test the API.

### Spring protocol
The [Spring Lobby protocol](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html) is the old protocol, in use until everything is ready to fully switch to Tachyon.

Over time the protocol has been extended with additional commands, mainly for the needs of Beyond All Reason, most are also handled by the Chobby client.<br>
The extensions add additional information to lobbies (e.g. team configurations and title updates), broadcast system events (e.g. shutdown) or make party management, user relationships management (e.g. friends, avoids) and reporting easier and possible through the client.

The documentation of the added commands is [here](documents/spring/extensions.md).

The relevant code for Spring protocol and it's extensions is mostly in the [this](lib/teiserver/protocols/spring) directory.

For testing Spring related features you will likely want to [set up SPADS](/documents/guides/spads_install.md).


### Discord bot
Teiserver also hosts a Discord bot.<br>
It was originally introduced as a bridge between Discord and game `#main` channels but has since been expanded with additional features, some of which are: posting moderation action messages and new report messages in the relevant Discord channels, support for custom commands (e.g. looking up units and text callbacks, checking your account stats), linking your Discord account to Teiserver (for receiving lobby/game notifications on Discord, e.g. exiting join queue, game starting), updating player/lobby counter channels on Discord.

> [!IMPORTANT]
> The Discord bot is intended to be used only on a single Discord server per Teiserver instance.

[Nostrum](https://hexdocs.pm/nostrum/intro.html) is the Elixir library used for interacting with Discord.

Most of the relevant Discord bridge bot code is in [this](lib/teiserver/bridge) directory.

If you want to develop the Discord bridge bot follow [this setup guide](https://github.com/beyond-all-reason/teiserver/blob/master/documents/guides/discord_bot.md).

### Rating
Teiserver is using the [Openskill](https://openskill.me/) rating system for rating players. 

> [!NOTE]
> For more information about Openskill and the rating and balancing system in general check out [this BAR official guide](https://www.beyondallreason.info/guide/rating-and-lobby-balance).

The Elixir Openskill library used by Teiserver and Beyond All Reason is [here](https://github.com/beyond-all-reason/openskill.ex).

### Balancing
Teiserver is responsible for balancing games based on Openskill ratings.
There are several balancing algorithms available, each with its own advantages and disadvantages.

Currently SPADS sends a balance request to Teiserver over SPADS API when it detects that the lobby state changed to require a rebalance or a `!balance` commands is used, Teiserver then balances the game using the default balance algorithm and returns the team configuration to SPADS.

Eventually we want to move the balance algorithms to some external solver which should be more performant and allow development of balance algorithms independently of Teiserver. No work has been done on this so far.

The balance alrogirhtms are located in [this](lib/teiserver/battle/balance) directory.

## Main 3rd party dependencies
The main dependencies of the project are:
- [Phoenix framework](https://www.phoenixframework.org/), a web framework with a role similar to Django or Rails.
- [Ecto](https://github.com/elixir-ecto/ecto), database ORM
- [Ranch](https://github.com/ninenines/ranch), a tcp server
- [Oban](https://github.com/sorentwo/oban), a backend job processing framework.