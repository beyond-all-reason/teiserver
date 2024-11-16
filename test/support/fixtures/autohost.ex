defmodule Teiserver.AutohostFixtures do
  alias Teiserver.Autohost

  def create_autohost() do
    name = for _ <- 1..20, into: "", do: <<Enum.random(?a..?z)>>
    create_autohost(name)
  end

  def create_autohost(name) do
    {:ok, autohost} = Autohost.create_autohost(%{name: name})
    autohost
  end
end
