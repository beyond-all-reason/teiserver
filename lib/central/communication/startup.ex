defmodule Central.Communication.Startup do
  use CentralWeb, :startup

  def startup do
    add_permission_set("communication", "blog", ~w(show create update delete export report))
    add_permission_set("communication", "chat", ~w(read write rooms send_direct))
  end
end
