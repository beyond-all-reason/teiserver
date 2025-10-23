# Welcome to BAR

There is documentation and guides under [documents/guides/](./documents/guides/).
Particularly relevant is the [development guide](./documents/guides/development.md) for getting started with developing teiserver.

# Running tests

The CI runs the tests, but you can speed up the process and run them locally

* `mix format`
* `mix dialyzer .`
* `mix test --exclude needs_attention`
