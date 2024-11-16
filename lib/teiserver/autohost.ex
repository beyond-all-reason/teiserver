defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.{Autohost, Registry}
  alias Teiserver.AutohostQueries
  alias Teiserver.Repo

  @type id :: Teiserver.Autohost.Autohost.id()
  @type reg_value :: Registry.reg_value()

  @type start_script :: %{
          battleId: String.t(),
          engineVersion: String.t(),
          gameName: String.t(),
          mapName: String.t(),
          startPosType: :fixed | :random | :ingame | :beforegame,
          allyTeams: [ally_team(), ...]
        }

  @type ally_team :: %{
          teams: [team(), ...]
        }

  @type team :: %{
          players: [player()]
        }

  @type player :: %{
          userId: String.t(),
          name: String.t(),
          password: String.t()
        }

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

  @spec list() :: [reg_value()]
  defdelegate list(), to: Registry

  @spec start_matchmaking(Autohost.id(), start_script()) ::
          {:ok, Teiserver.Autohost.TachyonHandler.start_response()}
          | {:error, term()}
  defdelegate start_matchmaking(autohost_id, start_script),
    to: Teiserver.Autohost.TachyonHandler
end
