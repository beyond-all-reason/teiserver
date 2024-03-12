defmodule Barserver.Telemetry.ComplexServerEventLib do
  @moduledoc false
  use BarserverWeb, :library_newform
  alias Barserver.Telemetry
  alias Barserver.Telemetry.{ComplexServerEvent, ComplexServerEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-database"

  @spec log_complex_server_event(T.userid() | nil, String, map()) ::
          {:error, Ecto.Changeset} | {:ok, ComplexServerEvent}
  def log_complex_server_event(userid, event_type_name, value) do
    event_type_id = Telemetry.get_or_add_complex_server_event_type(event_type_name)

    result =
      create_complex_server_event(%{
        user_id: userid,
        event_type_id: event_type_id,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Barserver.PubSub,
            "telemetry_complex_server_events",
            %{
              channel: "telemetry_complex_server_events",
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
  Returns the list of complex_server_events.

  ## Examples

      iex> list_complex_server_events()
      [%ComplexServerEvent{}, ...]

  """
  @spec list_complex_server_events(list) :: list
  def list_complex_server_events(args \\ []) do
    args
    |> ComplexServerEventQueries.query_complex_server_events()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_server_event.

  Raises `Ecto.NoResultsError` if the ComplexServerEvent does not exist.

  ## Examples

      iex> get_complex_server_event!(123)
      %ComplexServerEvent{}

      iex> get_complex_server_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_server_event!(id), do: Repo.get!(ComplexServerEvent, id)

  def get_complex_server_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexServerEventQueries.query_complex_server_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_server_event.

  ## Examples

      iex> create_complex_server_event(%{field: value})
      {:ok, %ComplexServerEvent{}}

      iex> create_complex_server_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_server_event(attrs \\ %{}) do
    %ComplexServerEvent{}
    |> ComplexServerEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_server_event.

  ## Examples

      iex> update_complex_server_event(complex_server_event, %{field: new_value})
      {:ok, %ComplexServerEvent{}}

      iex> update_complex_server_event(complex_server_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_server_event(%ComplexServerEvent{} = complex_server_event, attrs) do
    complex_server_event
    |> ComplexServerEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_server_event.

  ## Examples

      iex> delete_complex_server_event(complex_server_event)
      {:ok, %ComplexServerEvent{}}

      iex> delete_complex_server_event(complex_server_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_server_event(%ComplexServerEvent{} = complex_server_event) do
    Repo.delete(complex_server_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_server_event changes.

  ## Examples

      iex> change_complex_server_event(complex_server_event)
      %Ecto.Changeset{data: %ComplexServerEvent{}}

  """
  def change_complex_server_event(%ComplexServerEvent{} = complex_server_event, attrs \\ %{}) do
    ComplexServerEvent.changeset(complex_server_event, attrs)
  end
end
