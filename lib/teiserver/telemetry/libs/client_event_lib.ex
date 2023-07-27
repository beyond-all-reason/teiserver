defmodule Teiserver.Telemetry.ClientEventLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Telemetry.{ClientEvent, UnauthEvent, ClientEventTypeLib}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  # Functions
  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-sliders-up"

  # Helpers
  @spec log_client_event(integer | nil, String, map()) :: {:error, Ecto.Changeset} | {:ok, ClientEvent} | {:ok, UnauthEvent}
  def log_client_event(userid, event_type_name, value) when is_integer(userid) do
    log_client_event(userid, event_type_name, value, nil)
  end

  @spec log_client_event(integer | nil, String, map(), String | nil) :: {:error, Ecto.Changeset} | {:ok, ClientEvent} | {:ok, UnauthEvent}
  def log_client_event(nil, event_type_name, value, hash) do
    event_type_id = ClientEventTypeLib.get_or_add_client_event_type(event_type_name)

    Teiserver.Telemetry.create_unauth_event(%{
      event_type_id: event_type_id,
      hash: hash,
      value: value,
      timestamp: Timex.now()
    })
  end

  def log_client_event(userid, event_type_name, value, _hash) do
    event_type_id = ClientEventTypeLib.get_or_add_client_event_type(event_type_name)

    result =
      Teiserver.Telemetry.create_client_event(%{
        event_type_id: event_type_id,
        user_id: userid,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Central.PubSub,
            "teiserver_telemetry_client_events",
            %{
              channel: "teiserver_telemetry_client_events",
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

  @spec get_client_events_summary(list) :: map
  def get_client_events_summary(args) do
    query =
      from client_events in ClientEvent,
        join: event_types in assoc(client_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(client_events.event_type_id)}

    query
    |> search(args)
    |> Repo.all()
    |> Map.new()
  end

  # Queries
  @spec query_client_events() :: Ecto.Query.t()
  def query_client_events do
    from(client_events in ClientEvent)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from client_events in query,
      where: client_events.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_ids) do
    from client_events in query,
      where: client_events.user_id in ^user_ids
  end

  def _search(query, :id_list, id_list) do
    from client_events in query,
      where: client_events.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from client_events in query,
      where: between(client_events.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :event_type_id, event_type_id) do
    from client_events in query,
      where: client_events.event_type_id == ^event_type_id
  end

  def _search(query, :event_type_id_in, event_type_ids) do
    from client_events in query,
      where: client_events.event_type_id in ^event_type_ids
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from client_events in query,
      order_by: [asc: client_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from client_events in query,
      order_by: [desc: client_events.name]
  end

  def order_by(query, "Newest first") do
    from client_events in query,
      order_by: [desc: client_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from client_events in query,
      order_by: [asc: client_events.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :event_type in preloads, do: _preload_event_types(query), else: query
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  @spec _preload_event_types(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_event_types(query) do
    from client_events in query,
      left_join: event_types in assoc(client_events, :event_type),
      preload: [event_type: event_types]
  end

  @spec _preload_users(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_users(query) do
    from client_events in query,
      left_join: users in assoc(client_events, :user),
      preload: [user: users]
  end
end
