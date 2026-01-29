# Testing Guide

This document outlines the testing procedures for Teiserver. We support both local testing and a Docker-based workflow for a consistent environment.

> [!NOTE]
> For legacy testing documentation and specific debugging tips (like VSCode setup), please refer to [documents/guides/testing.md](documents/guides/testing.md).

## Docker Testing (Recommended)

The easiest way to run tests is using Docker Compose. This ensures you have the correct dependencies and database configuration without polluting your local machine.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running.

### Running Tests

To run the full test suite:

```bash
docker compose -f docker-compose.test.yml run --rm test
```

This command will:
1. Start a temporary Postgres database.
2. Build the Teiserver image (target: builder).
3. Run `mix test` inside the container.
4. Clean up the container afterwards (due to `--rm`).

### Running Specific Tests

You can pass arguments to the underlying `mix test` command. For example, to run a specific test file:

```bash
docker compose -f docker-compose.test.yml run --rm test mix test test/teiserver/account/auth_test.exs
```

Or to run a specific line:

```bash
docker compose -f docker-compose.test.yml run --rm test mix test test/teiserver/account/auth_test.exs:12
```

### Resetting the Environment

If you need to rebuild the image (e.g., after changing dependencies in `mix.exs`):

```bash
docker compose -f docker-compose.test.yml build
```

To stop the database container:

```bash
docker compose -f docker-compose.test.yml down
```

## Local Testing

If you prefer to run tests locally, ensure you have Elixir, Erlang, and Postgres installed.

1.  **Dependencies**:
    ```bash
    mix deps.get
    ```

2.  **Database Setup**:
    Make sure your Postgres database is running and configured in `config/test.exs` (or via environment variables).
    ```bash
    mix test.setup
    ```
    *(Note: `mix test` alias usually handles creation and migration, but you might need to run `mix ecto.create` and `mix ecto.migrate` manually if it's the first time.)*

3.  **Run Tests**:
    ```bash
    mix test
    ```

## Code Quality & Coverage

To check for code style and potential bugs:

```bash
# Security check
mix sobelow

# Code style
mix credo

# Static analysis
mix dialyzer
```

For test coverage (requires local setup usually, or mapped volume):

```bash
mix coveralls
```
