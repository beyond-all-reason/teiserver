# Teiserver
[![Build and test](https://github.com/beyond-all-reason/teiserver/actions/workflows/tests.yml/badge.svg?branch=master)](https://github.com/beyond-all-reason/teiserver/actions/workflows/tests.yml)

An Elixir middleware server for game management; primarily used by [Beyond all Reason](https://www.beyondallreason.info/). Currently implementing the Spring protocol but with work being done on a new protocol [Tachyon](https://github.com/beyond-all-reason/tachyon).

## Local setup
There are two ways to set up Teiserver locally for development or testing:

1. The [Local setup](/documents/guides/local_setup.md) guides you through the process of setting up everything yourself
2. The [Local testing](https://github.com/beyond-all-reason/ansible-teiserver?tab=readme-ov-file#local-testing) instructions use the Ansible playbook, which automates most of the setup and configuration.

## Prod setup
Production instance is set up using [Ansible playbook](https://github.com/beyond-all-reason/ansible-teiserver/tree/main), follow the setup instructions there.

## Development
Check the [development](/documents/guides/development.md) guide for help with getting started with Teiserver development.

## Documentation
- [Architecture](/documents/architecture.md)
- [Testing](/documents/guides/testing.md)

> [!NOTE]
> Check [BAR infrastructure documentation](https://beyond-all-reason.github.io/infrastructure/current_infra/) to see Teiserver's role in the larger BAR infrastructure.

### Contributing

All contributors are welcome; if you spot an issue or bug open an issue in this repo or visit *#teiserver-spads* channel on [BAR Discord](https://discord.gg/beyond-all-reason). Pull requests are also welcome; even if it's just a spelling mistake.


#### Special thanks

- Beherith for extensive help with the autohosts
- Skynet and AKU for extensive finding and reporting of bugs
