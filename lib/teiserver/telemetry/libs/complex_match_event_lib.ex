defmodule Teiserver.Telemetry.ComplexMatchEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{ComplexMatchEvent, ComplexMatchEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-chess-queen"

  @spec log_complex_match_event(T.userid(), T.match_id(), String, non_neg_integer, map()) ::
          {:error, Ecto.Changeset} | {:ok, ComplexLobbyEvent}
  def log_complex_match_event(userid, match_id, event_type_name, game_time, value) do
    event_type_id = Telemetry.get_or_add_complex_match_event_type(event_type_name)

    result =
      create_complex_match_event(%{
        user_id: userid,
        event_type_id: event_type_id,
        match_id: match_id,
        game_time: game_time,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_complex_match_events",
            %{
              channel: "telemetry_complex_match_events",
              match_id: match_id,
              userid: userid,
              event_type_name: event_type_name,
              game_time: game_time,
              event_value: value
            }
          )
        end

        result

      _ ->
        result
    end
  end

  @doc """
  Returns the list of complex_match_events.

  ## Examples

      iex> list_complex_match_events()
      [%ComplexMatchEvent{}, ...]

  """
  @spec list_complex_match_events(list) :: list
  def list_complex_match_events(args \\ []) do
    args
    |> ComplexMatchEventQueries.query_complex_match_events()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_match_event.

  Raises `Ecto.NoResultsError` if the ComplexMatchEvent does not exist.

  ## Examples

      iex> get_complex_match_event!(123)
      %ComplexMatchEvent{}

      iex> get_complex_match_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_match_event!(id), do: Repo.get!(ComplexMatchEvent, id)

  def get_complex_match_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexMatchEventQueries.query_complex_match_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_match_event.

  ## Examples

      iex> create_complex_match_event(%{field: value})
      {:ok, %ComplexMatchEvent{}}

      iex> create_complex_match_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_match_event(attrs \\ %{}) do
    %ComplexMatchEvent{}
    |> ComplexMatchEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_match_event.

  ## Examples

      iex> update_complex_match_event(complex_match_event, %{field: new_value})
      {:ok, %ComplexMatchEvent{}}

      iex> update_complex_match_event(complex_match_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_match_event(%ComplexMatchEvent{} = complex_match_event, attrs) do
    complex_match_event
    |> ComplexMatchEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_match_event.

  ## Examples

      iex> delete_complex_match_event(complex_match_event)
      {:ok, %ComplexMatchEvent{}}

      iex> delete_complex_match_event(complex_match_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_match_event(%ComplexMatchEvent{} = complex_match_event) do
    Repo.delete(complex_match_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_match_event changes.

  ## Examples

      iex> change_complex_match_event(complex_match_event)
      %Ecto.Changeset{data: %ComplexMatchEvent{}}

  """
  def change_complex_match_event(%ComplexMatchEvent{} = complex_match_event, attrs \\ %{}) do
    ComplexMatchEvent.changeset(complex_match_event, attrs)
  end
end
