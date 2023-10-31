defmodule Teiserver.Repo do
  use Ecto.Repo,
    otp_app: :teiserver,
    adapter: Ecto.Adapters.Postgres
end
