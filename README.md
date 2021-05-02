# Teiserver
An Elixir centralised/middleware game server. Originally an alternate implementation of [Uberserver](https://github.com/spring/uberserver) as used by Spring RTS games. Currently implementing only the Spring protocol but later I plan to create a new and more modern protocol and am open to implementing other existing protocols. Being written in Elixir it takes full advantage of the Erlang OTP for a very concurrent application with very low demand on system resources.

## Documentation
- [Architecture](/documents/architecture.md)
- [Local setup](/documents/guides/local_setup.md)
- [Prod setup linux](/documents/guides/production_setup_linux.md)/[Prod setup windows](/documents/guides/production_setup_windows.md)
- [Testing](/documents/guides/testing.md)
- [Uberserver, conversion process and differences](/documents/guides/uberserver.md)

These are just the highlights, full documentation can be found in the documentation folder.

### High level TODO list (no particular order)
- [Matchmaking](/documents/spring/matchmaking.md)
- [Parties](/documents/spring/parties.md)
- [Clans](/documents/designs/clans.md)
- [Teiserver boss mode](/documents/designs/teiserver_boss.md)
- Integration with Discord/other services
- [Reputation/Reporting system](/documents/designs/reputation.md)
- [Metrics](/documents/designs/metrics.md)
- [Agent mode/Lobby dev assist](/documents/designs/agent_mode.md)

### Contributing
All contributors are welcome; if you spot an issue or bug with it mention me on the [BAR discord](https://discord.gg/N968ddE) (@teifion) or open an issue in this repo. Pull requests are also welcome; even if it's just a matter of spelling mistake.

#### Special thanks
- Beherith for extensive help with the autohosts
- Skynet for finding those hard to spot bits of the protocol I'd missed, check out his [Skylobby](https://github.com/skynet-gh/skylobby) project
