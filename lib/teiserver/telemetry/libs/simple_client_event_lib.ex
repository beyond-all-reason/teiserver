defmodule Teiserver.Telemetry.SimpleClientEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{SimpleClientEvent, SimpleClientEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-grip-lines"

  @spec log_simple_client_event(T.userid(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, SimpleClientEvent}
  def log_simple_client_event(userid, event_type_name) when is_integer(userid) do
    event_type_id = Telemetry.get_or_add_simple_client_event_type(event_type_name)

    result =
      create_simple_client_event(%{
        user_id: userid,
        event_type_id: event_type_id,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_simple_client_events",
            %{
              channel: "telemetry_simple_client_events",
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
  Returns the list of simple_client_events.

  ## Examples

      iex> list_simple_client_events()
      [%SimpleClientEvent{}, ...]

  """
  @spec list_simple_client_events(list) :: list
  def list_simple_client_events(args \\ []) do
    args
    |> SimpleClientEventQueries.query_simple_client_events()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_client_event.

  Raises `Ecto.NoResultsError` if the SimpleClientEvent does not exist.

  ## Examples

      iex> get_simple_client_event!(123)
      %SimpleClientEvent{}

      iex> get_simple_client_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_client_event!(id), do: Repo.get!(SimpleClientEvent, id)

  def get_simple_client_event!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleClientEventQueries.query_simple_client_events()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_client_event.

  ## Examples

      iex> create_simple_client_event(%{field: value})
      {:ok, %SimpleClientEvent{}}

      iex> create_simple_client_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_client_event(attrs \\ %{}) do
    %SimpleClientEvent{}
    |> SimpleClientEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_client_event.

  ## Examples

      iex> update_simple_client_event(simple_client_event, %{field: new_value})
      {:ok, %SimpleClientEvent{}}

      iex> update_simple_client_event(simple_client_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_client_event(%SimpleClientEvent{} = simple_client_event, attrs) do
    simple_client_event
    |> SimpleClientEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_client_event.

  ## Examples

      iex> delete_simple_client_event(simple_client_event)
      {:ok, %SimpleClientEvent{}}

      iex> delete_simple_client_event(simple_client_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_client_event(%SimpleClientEvent{} = simple_client_event) do
    Repo.delete(simple_client_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_client_event changes.

  ## Examples

      iex> change_simple_client_event(simple_client_event)
      %Ecto.Changeset{data: %SimpleClientEvent{}}

  """
  def change_simple_client_event(%SimpleClientEvent{} = simple_client_event, attrs \\ %{}) do
    SimpleClientEvent.changeset(simple_client_event, attrs)
  end
end
