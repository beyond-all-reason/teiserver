ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Teiserver.Repo, :manual)

alias Teiserver.Helpers.GeneralTestLib
alias Teiserver.Repo

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

if not GeneralTestLib.seeded?() do
  GeneralTestLib.seed()
  Teiserver.TeiserverTestLib.seed()
end

Ecto.Adapters.SQL.Sandbox.checkin(Repo)
