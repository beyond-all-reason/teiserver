In theory this should work fine on windows. Unfortunately I've no idea how to go about installing it on Windows. If anybody wants to install it on Windows then I've listed below the key items used in the [linux](/documents/dev_guides/production_setup_linux.md) setup process.

- Elixir of course for the application
- Nginx as a web proxy routing to the Phoenix application, phoenix is listening on port 8888
- Lets encrypt for the SSL cert
- Postgres as a database. If you need a different database it should be possible to do that with various [Ecto](https://hexdocs.pm/ecto/Ecto.html) configurations but postgres is what I've used and tested

I would welcome any PRs which can provide even the smallest documentation for this.
