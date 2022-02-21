# Teiserver
An Elixir centralised/middleware game server. Originally an alternate implementation of [Uberserver](https://github.com/spring/uberserver) as used by Spring RTS games. Currently implementing only the Spring protocol but later I plan to create a new and more modern protocol and am open to implementing other existing protocols. Being written in Elixir it takes full advantage of the Erlang OTP for a very concurrent application with very low demand on system resources.

## Documentation
- [Architecture](/documents/architecture.md)
- [Local setup](/documents/dev_guides/local_setup.md)
- [Prod setup linux](/documents/dev_guides/production_setup_linux.md)/[Prod setup windows](/documents/dev_guides/production_setup_windows.md)
- [Testing](/documents/dev_guides/testing.md)
- [Uberserver, conversion process and differences](/documents/dev_guides/uberserver.md)

These are just the highlights, full documentation can be found in the documentation folder.

### Feature documentation
- [Metrics](/documents/planned_designs/metrics.md)
- [Agent mode/Lobby dev assist](/documents/dev_guides/discord_bot.md)

### In progress features
- [Coordinator mode](/documents/planned_designs/coordinator.md)
- [Matchmaking](/documents/spring/matchmaking.md)
- [Reputation/Reporting system](/documents/planned_designs/reputation.md)
- [Tachyon](/documents/tachyon)
- [Agent mode/Lobby dev assist](/documents/planned_designs/agent_mode.md)

### Features planned but not started
- [Parties](/documents/spring/parties.md)
- [Clans](/documents/planned_designs/clans.md)

### Contributing
All contributors are welcome; if you spot an issue or bug with it mention me on the [BAR discord](https://discord.gg/N968ddE) (@teifion) or open an issue in this repo. Pull requests are also welcome; even if it's just a spelling mistake.

#### Special thanks
- Beherith for extensive help with the autohosts
- Skynet and AKU for extensive finding of and reporting bugs
