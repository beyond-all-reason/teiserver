defmodule Central.Admin.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    add_permission_set("debug", "debug", ~w(debug))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "group", ~w(show create update delete report))
    add_permission_set("admin", "admin", ~w(limited full))
  end
end
