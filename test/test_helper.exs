ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Teiserver.Repo, :manual)

alias Teiserver.Repo

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

Ecto.Adapters.SQL.Sandbox.checkin(Repo)
