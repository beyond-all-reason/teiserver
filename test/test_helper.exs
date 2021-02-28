ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Central.Repo, :manual)

alias Central.Repo
alias Central.Helpers.GeneralTestLib

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

if not GeneralTestLib.seeded?() do
  GeneralTestLib.seed()
end

Ecto.Adapters.SQL.Sandbox.checkin(Repo)
