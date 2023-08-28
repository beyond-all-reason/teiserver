defmodule Teiserver.Telemetry.SimpleAnonEventLib do
  @moduledoc false
  use CentralWeb, :library_newform
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{SimpleAnonEvent, SimpleAnonEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t
  def icon(), do: "fa-sliders-up"

  @spec log_simple_anon_event(String.t, String.t, map) :: {:error, Ecto.Changeset} | {:ok, SimpleAnonEvent}
  def log_simple_anon_event(hash, event_type_name, value) do
    event_type_id = Telemetry.get_or_add_simple_client_event_type(event_type_name)

    result = create_simple_anon_event(%{
      hash: hash,
      event_type_id: event_type_id,
      value: value,
      timestamp: Timex.now()
    })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_simple_anon_events",
            %{
              channel: "telemetry_simple_anon_events",
              hash: hash,
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
  Returns the list of simple_anon_events.

  ## Examples

      iex> list_simple_anon_events()
      [%SimpleAnonEvent{}, ...]

  """
  @spec list_simple_anon_events(list) :: list
  def list_simple_anon_events(args \\ []) do
    args
    |> SimpleAnonEventQueries.query_simple_anon_events()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_anon_event.

  Raises `Ecto.NoResultsError` if the SimpleAnonEvent does not exist.

  ## Examples

      iex> get_simple_anon_event!(123)
      %SimpleAnonEvent{}

      iex> get_simple_anon_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_anon_event!(id), do: Repo.get!(SimpleAnonEvent, id)

  def get_simple_anon_event!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleAnonEventQueries.query_simple_anon_events()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_anon_event.

  ## Examples

      iex> create_simple_anon_event(%{field: value})
      {:ok, %SimpleAnonEvent{}}

      iex> create_simple_anon_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_anon_event(attrs \\ %{}) do
    %SimpleAnonEvent{}
    |> SimpleAnonEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_anon_event.

  ## Examples

      iex> update_simple_anon_event(simple_anon_event, %{field: new_value})
      {:ok, %SimpleAnonEvent{}}

      iex> update_simple_anon_event(simple_anon_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_anon_event(%SimpleAnonEvent{} = simple_anon_event, attrs) do
    simple_anon_event
    |> SimpleAnonEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_anon_event.

  ## Examples

      iex> delete_simple_anon_event(simple_anon_event)
      {:ok, %SimpleAnonEvent{}}

      iex> delete_simple_anon_event(simple_anon_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_anon_event(%SimpleAnonEvent{} = simple_anon_event) do
    Repo.delete(simple_anon_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_anon_event changes.

  ## Examples

      iex> change_simple_anon_event(simple_anon_event)
      %Ecto.Changeset{data: %SimpleAnonEvent{}}

  """
  def change_simple_anon_event(%SimpleAnonEvent{} = simple_anon_event, attrs \\ %{}) do
    SimpleAnonEvent.changeset(simple_anon_event, attrs)
  end
end
