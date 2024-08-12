defmodule Teiserver.Logging.Startup do
  @moduledoc false
  use TeiserverWeb, :startup

  def startup do
    add_permission_set("logging", "page_view", ~w(show delete report))
    add_permission_set("logging", "aggregate", ~w(show delete report))
    add_permission_set("logging", "audit", ~w(show delete report))
    add_permission_set("logging", "error", ~w(show delete report))
    add_permission_set("logging", "live", ~w(show))
    :ok
  end
end
