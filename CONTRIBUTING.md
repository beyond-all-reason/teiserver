# Welcome to BAR

There is documentation and guides under [documents/guides/](./documents/guides/).
Particularly relevant is the [local setup guide](./documents/guides/local_setup.md) to get started
developping teiserver.

# Running tests

The CI runs the tests, but you can speed up the process and run them locally

* `mix format`
* `mix dialyzer .`
* `mix test --exclude needs_attention`
