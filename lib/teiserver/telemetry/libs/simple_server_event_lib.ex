defmodule Teiserver.Telemetry.SimpleServerEventLib do
  @moduledoc false
  use CentralWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{SimpleServerEvent, SimpleServerEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t
  def icon(), do: "fa-server"

  @spec log_simple_server_event(integer, String.t) :: {:error, Ecto.Changeset} | {:ok, SimpleServerEvent}
  def log_simple_server_event(userid, event_type_name) when is_integer(userid) do
    event_type_id = Telemetry.get_or_add_simple_server_event_type(event_type_name)

    result = create_simple_server_event(%{
      user_id: userid,
      event_type_id: event_type_id,
      timestamp: Timex.now()
    })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_simple_server_events",
            %{
              channel: "telemetry_simple_server_events",
              userid: userid,
              event_type_name: event_type_name
            }
          )
        end

        result

      _ ->
        result
    end
  end

  @doc """
  Returns the list of simple_server_events.

  ## Examples

      iex> list_simple_server_events()
      [%SimpleServerEvent{}, ...]

  """
  @spec list_simple_server_events(list) :: list
  def list_simple_server_events(args \\ []) do
    args
    |> SimpleServerEventQueries.query_simple_server_events()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_server_event.

  Raises `Ecto.NoResultsError` if the SimpleServerEvent does not exist.

  ## Examples

      iex> get_simple_server_event!(123)
      %SimpleServerEvent{}

      iex> get_simple_server_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_server_event!(id), do: Repo.get!(SimpleServerEvent, id)

  def get_simple_server_event!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleServerEventQueries.query_simple_server_events()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_server_event.

  ## Examples

      iex> create_simple_server_event(%{field: value})
      {:ok, %SimpleServerEvent{}}

      iex> create_simple_server_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_server_event(attrs \\ %{}) do
    %SimpleServerEvent{}
    |> SimpleServerEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_server_event.

  ## Examples

      iex> update_simple_server_event(simple_server_event, %{field: new_value})
      {:ok, %SimpleServerEvent{}}

      iex> update_simple_server_event(simple_server_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_server_event(%SimpleServerEvent{} = simple_server_event, attrs) do
    simple_server_event
    |> SimpleServerEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_server_event.

  ## Examples

      iex> delete_simple_server_event(simple_server_event)
      {:ok, %SimpleServerEvent{}}

      iex> delete_simple_server_event(simple_server_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_server_event(%SimpleServerEvent{} = simple_server_event) do
    Repo.delete(simple_server_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_server_event changes.

  ## Examples

      iex> change_simple_server_event(simple_server_event)
      %Ecto.Changeset{data: %SimpleServerEvent{}}

  """
  def change_simple_server_event(%SimpleServerEvent{} = simple_server_event, attrs \\ %{}) do
    SimpleServerEvent.changeset(simple_server_event, attrs)
  end
end
