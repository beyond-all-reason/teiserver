defmodule Teiserver.AutohostFixtures do
  alias Teiserver.Autohost

  def create_autohost(name) do
    {:ok, autohost} = Autohost.create_autohost(%{name: name})
    autohost
  end
end
