# Teiserver
An Elixir centralised/middleware game server. Originally an alternate implementation of [Uberserver](https://github.com/spring/uberserver) as used by Spring RTS games. Currently implementing the Spring protocol but with work being done on a new protocol [Tachyon](/documents/tachyon).

It takes full advantage of Elixir/OTP for a fully concurrent application with very low demand on system resources. Work is currently being undertaken to make it suitable for a clustered deployment.

## Documentation
- [Architecture](/documents/architecture.md)
- [Local setup](/documents/guides/local_setup.md)
- [Prod setup linux](/documents/guides/production_setup_linux.md)/[Prod setup windows](/documents/guides/production_setup_windows.md)
- [Testing](/documents/guides/testing.md)
- [Uberserver, conversion process and differences](/documents/guides/uberserver.md)

These are just the highlights, full documentation can be found in the documentation folder.

### Feature documentation
- [Metrics](/documents/planned_designs/metrics.md)
- [Discord bot](/documents/guides/discord_bot.md)

### In progress features
- [Tachyon](/documents/tachyon)
- [Clustering](/documents/planned_designs/clustering.md)
- [Matchmaking](/documents/spring/matchmaking.md)
- [Reputation/Reporting system](/documents/planned_designs/reputation.md)
- [Agent mode/Lobby dev assist](/documents/planned_designs/agent_mode.md)
- [Parties](/documents/spring/parties.md)

### Features planned but not started
- [Clans](/documents/planned_designs/clans.md)

### Contributing
All contributors are welcome; if you spot an issue or bug with it mention me on the [BAR discord](https://discord.gg/N968ddE) (@teifion) or open an issue in this repo. Pull requests are also welcome; even if it's just a spelling mistake.

#### Special thanks
- Beherith for extensive help with the autohosts
- Skynet and AKU for extensive finding and reporting of bugs
