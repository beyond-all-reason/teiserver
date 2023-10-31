defmodule Teiserver.Telemetry.ComplexLobbyEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{ComplexLobbyEvent, ComplexLobbyEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-people-group"

  @spec log_complex_lobby_event(T.userid, T.match_id, String, map()) :: {:error, Ecto.Changeset} | {:ok, ComplexLobbyEvent}
  def log_complex_lobby_event(userid, match_id, event_type_name, value) do
    event_type_id = Telemetry.get_or_add_complex_lobby_event_type(event_type_name)

    result = create_complex_lobby_event(%{
      user_id: userid,
      match_id: match_id,
      event_type_id: event_type_id,
      value: value,
      timestamp: Timex.now()
    })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_complex_lobby_events",
            %{
              channel: "telemetry_complex_lobby_events",
              match_id: match_id,
              userid: userid,
              event_type_name: event_type_name,
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
  Returns the list of complex_lobby_events.

  ## Examples

      iex> list_complex_lobby_events()
      [%ComplexLobbyEvent{}, ...]

  """
  @spec list_complex_lobby_events(list) :: list
  def list_complex_lobby_events(args \\ []) do
    args
    |> ComplexLobbyEventQueries.query_complex_lobby_events()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_lobby_event.

  Raises `Ecto.NoResultsError` if the ComplexLobbyEvent does not exist.

  ## Examples

      iex> get_complex_lobby_event!(123)
      %ComplexLobbyEvent{}

      iex> get_complex_lobby_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_lobby_event!(id), do: Repo.get!(ComplexLobbyEvent, id)

  def get_complex_lobby_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexLobbyEventQueries.query_complex_lobby_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_lobby_event.

  ## Examples

      iex> create_complex_lobby_event(%{field: value})
      {:ok, %ComplexLobbyEvent{}}

      iex> create_complex_lobby_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_lobby_event(attrs \\ %{}) do
    %ComplexLobbyEvent{}
    |> ComplexLobbyEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_lobby_event.

  ## Examples

      iex> update_complex_lobby_event(complex_lobby_event, %{field: new_value})
      {:ok, %ComplexLobbyEvent{}}

      iex> update_complex_lobby_event(complex_lobby_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_lobby_event(%ComplexLobbyEvent{} = complex_lobby_event, attrs) do
    complex_lobby_event
    |> ComplexLobbyEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_lobby_event.

  ## Examples

      iex> delete_complex_lobby_event(complex_lobby_event)
      {:ok, %ComplexLobbyEvent{}}

      iex> delete_complex_lobby_event(complex_lobby_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_lobby_event(%ComplexLobbyEvent{} = complex_lobby_event) do
    Repo.delete(complex_lobby_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_lobby_event changes.

  ## Examples

      iex> change_complex_lobby_event(complex_lobby_event)
      %Ecto.Changeset{data: %ComplexLobbyEvent{}}

  """
  def change_complex_lobby_event(%ComplexLobbyEvent{} = complex_lobby_event, attrs \\ %{}) do
    ComplexLobbyEvent.changeset(complex_lobby_event, attrs)
  end
end
