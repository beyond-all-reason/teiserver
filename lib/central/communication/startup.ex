defmodule Central.Communication.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    if Application.get_env(:central, Central)[:enable_blog] do
      add_permission_set("communication", "blog", ~w(show create update delete export report))
    end

    add_permission_set("communication", "chat", ~w(read write rooms send_direct))
  end
end
