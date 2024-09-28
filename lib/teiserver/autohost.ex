defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.{Autohost, Registry}
  alias Teiserver.AutohostQueries
  alias Teiserver.Repo

  @type reg_value :: Registry.reg_value()

  def create_autohost(attrs \\ %{}) do
    %Autohost{}
    |> Autohost.changeset(attrs)
    |> Repo.insert()
  end

  def change_autohost(%Autohost{} = autohost, attrs \\ %{}) do
    Autohost.changeset(autohost, attrs)
  end

  def update_autohost(%Autohost{} = autohost, attrs) do
    autohost |> change_autohost(attrs) |> Repo.update()
  end

  @spec delete(Autohost.t()) :: :ok | {:error, term()}
  def delete(%Autohost{} = autohost) do
    case Repo.delete(autohost) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defdelegate get_by_id(id), to: AutohostQueries

  @doc """
  Returns the pid of the autohost registered with a given id
  """
  @spec lookup_autohost(Autohost.id()) :: {pid(), reg_value()} | nil
  def lookup_autohost(autohost_id) do
    Teiserver.Autohost.Registry.lookup(autohost_id)
  end
end
