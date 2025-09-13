defmodule Teiserver.Telemetry.SimpleMatchEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{SimpleMatchEvent, SimpleMatchEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-chess-pawn"

  @spec log_simple_match_event(T.userid(), T.match_id(), String.t(), non_neg_integer) ::
          {:error, Ecto.Changeset} | {:ok, SimpleMatchEvent}
  def log_simple_match_event(userid, match_id, event_type_name, game_time) do
    event_type_id = Telemetry.get_or_add_simple_match_event_type(event_type_name)

    result =
      create_simple_match_event(%{
        user_id: userid,
        event_type_id: event_type_id,
        match_id: match_id,
        game_time: game_time
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_simple_match_events",
            %{
              channel: "telemetry_simple_match_events",
              userid: userid,
              match_id: match_id,
              game_time: game_time,
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
  Returns the list of simple_match_events.

  ## Examples

      iex> list_simple_match_events()
      [%SimpleMatchEvent{}, ...]

  """
  @spec list_simple_match_events(list) :: list
  def list_simple_match_events(args \\ []) do
    args
    |> SimpleMatchEventQueries.query_simple_match_events()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_match_event.

  Raises `Ecto.NoResultsError` if the SimpleMatchEvent does not exist.

  ## Examples

      iex> get_simple_match_event!(123)
      %SimpleMatchEvent{}

      iex> get_simple_match_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_match_event!(id), do: Repo.get!(SimpleMatchEvent, id)

  def get_simple_match_event!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleMatchEventQueries.query_simple_match_events()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_match_event.

  ## Examples

      iex> create_simple_match_event(%{field: value})
      {:ok, %SimpleMatchEvent{}}

      iex> create_simple_match_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_match_event(attrs \\ %{}) do
    %SimpleMatchEvent{}
    |> SimpleMatchEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_match_event.

  ## Examples

      iex> update_simple_match_event(simple_match_event, %{field: new_value})
      {:ok, %SimpleMatchEvent{}}

      iex> update_simple_match_event(simple_match_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_match_event(%SimpleMatchEvent{} = simple_match_event, attrs) do
    simple_match_event
    |> SimpleMatchEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_match_event.

  ## Examples

      iex> delete_simple_match_event(simple_match_event)
      {:ok, %SimpleMatchEvent{}}

      iex> delete_simple_match_event(simple_match_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_match_event(%SimpleMatchEvent{} = simple_match_event) do
    Repo.delete(simple_match_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_match_event changes.

  ## Examples

      iex> change_simple_match_event(simple_match_event)
      %Ecto.Changeset{data: %SimpleMatchEvent{}}

  """
  def change_simple_match_event(%SimpleMatchEvent{} = simple_match_event, attrs \\ %{}) do
    SimpleMatchEvent.changeset(simple_match_event, attrs)
  end
end
