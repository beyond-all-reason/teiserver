defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.Autohost
  alias Teiserver.Repo

  def create_autohost(attrs \\ %{}) do
    %Autohost{}
    |> Autohost.changeset(attrs)
    |> Repo.insert()
  end

  defdelegate get_autohost(id), to: Teiserver.AutohostQueries
end
