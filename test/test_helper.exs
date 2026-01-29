ExUnit.start(exclude: [:needs_attention])
Ecto.Adapters.SQL.Sandbox.mode(Teiserver.Repo, :manual)

alias Teiserver.Repo
alias Central.Helpers.GeneralTestLib

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

if not GeneralTestLib.seeded?() do
  GeneralTestLib.seed()
  Teiserver.TeiserverTestLib.seed()
end

Ecto.Adapters.SQL.Sandbox.checkin(Repo)
