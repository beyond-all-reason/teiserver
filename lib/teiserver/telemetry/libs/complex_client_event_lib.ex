defmodule Teiserver.Telemetry.ComplexClientEventLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{ComplexClientEvent, ComplexClientEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-sliders"

  @spec log_complex_client_event(integer, String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexClientEvent}
  def log_complex_client_event(userid, event_type_name, value) when is_integer(userid) do
    event_type_id = Telemetry.get_or_add_complex_client_event_type(event_type_name)

    result =
      create_complex_client_event(%{
        user_id: userid,
        event_type_id: event_type_id,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_complex_client_events",
            %{
              channel: "telemetry_complex_client_events",
              userid: userid,
              event_type_id: event_type_id,
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
  Returns the list of complex_client_events.

  ## Examples

      iex> list_complex_client_events()
      [%ComplexClientEvent{}, ...]

  """
  @spec list_complex_client_events(list) :: list
  def list_complex_client_events(args \\ []) do
    args
    |> ComplexClientEventQueries.query_complex_client_events()
    |> QueryHelpers.limit_query(args[:limit] || 500)
    |> Repo.all()
  end

  @doc """
  Gets a single complex_client_event.

  Raises `Ecto.NoResultsError` if the ComplexClientEvent does not exist.

  ## Examples

      iex> get_complex_client_event!(123)
      %ComplexClientEvent{}

      iex> get_complex_client_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_client_event!(id), do: Repo.get!(ComplexClientEvent, id)

  def get_complex_client_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexClientEventQueries.query_complex_client_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_client_event.

  ## Examples

      iex> create_complex_client_event(%{field: value})
      {:ok, %ComplexClientEvent{}}

      iex> create_complex_client_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_client_event(attrs \\ %{}) do
    %ComplexClientEvent{}
    |> ComplexClientEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_client_event.

  ## Examples

      iex> update_complex_client_event(complex_client_event, %{field: new_value})
      {:ok, %ComplexClientEvent{}}

      iex> update_complex_client_event(complex_client_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_client_event(%ComplexClientEvent{} = complex_client_event, attrs) do
    complex_client_event
    |> ComplexClientEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_client_event.

  ## Examples

      iex> delete_complex_client_event(complex_client_event)
      {:ok, %ComplexClientEvent{}}

      iex> delete_complex_client_event(complex_client_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_client_event(%ComplexClientEvent{} = complex_client_event) do
    Repo.delete(complex_client_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_client_event changes.

  ## Examples

      iex> change_complex_client_event(complex_client_event)
      %Ecto.Changeset{data: %ComplexClientEvent{}}

  """
  def change_complex_client_event(%ComplexClientEvent{} = complex_client_event, attrs \\ %{}) do
    ComplexClientEvent.changeset(complex_client_event, attrs)
  end
end
