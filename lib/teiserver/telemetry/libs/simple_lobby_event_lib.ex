defmodule Teiserver.Telemetry.SimpleLobbyEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{SimpleLobbyEvent, SimpleLobbyEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t
  def icon(), do: "fa-user-group"

  @spec log_simple_lobby_event(T.userid, T.match_id, String.t) :: {:error, Ecto.Changeset} | {:ok, SimpleLobbyEvent}
  def log_simple_lobby_event(userid, match_id, event_type_name) do
    event_type_id = Telemetry.get_or_add_simple_lobby_event_type(event_type_name)

    result = create_simple_lobby_event(%{
      user_id: userid,
      event_type_id: event_type_id,
      match_id: match_id,
      timestamp: Timex.now()
    })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_simple_lobby_events",
            %{
              channel: "telemetry_simple_lobby_events",
              userid: userid,
              match_id: match_id,
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
  Returns the list of simple_lobby_events.

  ## Examples

      iex> list_simple_lobby_events()
      [%SimpleLobbyEvent{}, ...]

  """
  @spec list_simple_lobby_events(list) :: list
  def list_simple_lobby_events(args \\ []) do
    args
    |> SimpleLobbyEventQueries.query_simple_lobby_events()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_lobby_event.

  Raises `Ecto.NoResultsError` if the SimpleLobbyEvent does not exist.

  ## Examples

      iex> get_simple_lobby_event!(123)
      %SimpleLobbyEvent{}

      iex> get_simple_lobby_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_lobby_event!(id), do: Repo.get!(SimpleLobbyEvent, id)

  def get_simple_lobby_event!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleLobbyEventQueries.query_simple_lobby_events()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_lobby_event.

  ## Examples

      iex> create_simple_lobby_event(%{field: value})
      {:ok, %SimpleLobbyEvent{}}

      iex> create_simple_lobby_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_lobby_event(attrs \\ %{}) do
    %SimpleLobbyEvent{}
    |> SimpleLobbyEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_lobby_event.

  ## Examples

      iex> update_simple_lobby_event(simple_lobby_event, %{field: new_value})
      {:ok, %SimpleLobbyEvent{}}

      iex> update_simple_lobby_event(simple_lobby_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_lobby_event(%SimpleLobbyEvent{} = simple_lobby_event, attrs) do
    simple_lobby_event
    |> SimpleLobbyEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_lobby_event.

  ## Examples

      iex> delete_simple_lobby_event(simple_lobby_event)
      {:ok, %SimpleLobbyEvent{}}

      iex> delete_simple_lobby_event(simple_lobby_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_lobby_event(%SimpleLobbyEvent{} = simple_lobby_event) do
    Repo.delete(simple_lobby_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_lobby_event changes.

  ## Examples

      iex> change_simple_lobby_event(simple_lobby_event)
      %Ecto.Changeset{data: %SimpleLobbyEvent{}}

  """
  def change_simple_lobby_event(%SimpleLobbyEvent{} = simple_lobby_event, attrs \\ %{}) do
    SimpleLobbyEvent.changeset(simple_lobby_event, attrs)
  end
end
