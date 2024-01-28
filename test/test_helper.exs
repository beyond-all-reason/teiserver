ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Barserver.Repo, :manual)

alias Barserver.Repo
alias Central.Helpers.GeneralTestLib

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

if not GeneralTestLib.seeded?() do
  GeneralTestLib.seed()
  Barserver.BarserverTestLib.seed()
end

Ecto.Adapters.SQL.Sandbox.checkin(Repo)
