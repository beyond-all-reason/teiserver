defmodule Mix.Tasks.Teiserver.TachyonSetup do
  @usage_str "Usage: `mix teiserver.tachyon_setup`"

  @moduledoc """
  Ensure there is an OAuth app for tachyon lobby and another one to control
  assets like maps and engines with bots.

  #{@usage_str}
  """

  @shortdoc "setup oauth apps for tachyon"

  use Mix.Task
  alias Teiserver.Tachyon.Tasks.SetupApps

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started([:ecto, :ecto_sql, :tzdata])
    Teiserver.Repo.start_link()
    SetupApps.ensure_lobby_app()
    SetupApps.ensure_asset_admin_app()
  end
end
