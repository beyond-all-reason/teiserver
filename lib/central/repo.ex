defmodule Central.Repo do
  use Ecto.Repo,
    otp_app: :central,
    adapter: Ecto.Adapters.Postgres
end
