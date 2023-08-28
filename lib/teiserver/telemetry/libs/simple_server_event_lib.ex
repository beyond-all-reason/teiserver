defmodule Teiserver.Telemetry.SimpleServerEventLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Telemetry.{SimpleServerEvent, SimpleServerEventTypeLib}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  # Functions
  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-server"

  # Helpers
  @spec log_simple_server_event(T.userid() | nil, String.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, SimpleServerEvent.t()}
  def log_simple_server_event(userid, event_type_name) do
    event_type_id = SimpleServerEventTypeLib.get_or_add_simple_server_event_type(event_type_name)

    result =
      Teiserver.Telemetry.create_simple_server_event(%{
        event_type_id: event_type_id,
        user_id: userid,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          if userid do
            PubSub.broadcast(
              Teiserver.PubSub,
              "teiserver_telemetry_simple_server_events",
              %{
                channel: "teiserver_telemetry_simple_server_events",
                userid: userid,
                event_type_name: event_type_name
              }
            )
          end
        end

        result

      _ ->
        result
    end
  end

  @spec get_simple_server_events_summary(list) :: map()
  def get_simple_server_events_summary(args) do
    query =
      from simple_server_events in SimpleServerEvent,
        join: event_types in assoc(simple_server_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(simple_server_events.event_type_id)}

    query
    |> search(args)
    |> Repo.all()
    |> Map.new()
  end

  # Queries
  @spec query_simple_server_events() :: Ecto.Query.t()
  def query_simple_server_events do
    from(simple_server_events in SimpleServerEvent)
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
    from simple_server_events in query,
      where: simple_server_events.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_ids) do
    from simple_server_events in query,
      where: simple_server_events.user_id in ^user_ids
  end

  def _search(query, :id_list, id_list) do
    from simple_server_events in query,
      where: simple_server_events.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from simple_server_events in query,
      where: between(simple_server_events.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :event_type_id, event_type_id) do
    from simple_server_events in query,
      where: simple_server_events.event_type_id == ^event_type_id
  end

  def _search(query, :event_type_id_in, event_type_ids) do
    from simple_server_events in query,
      where: simple_server_events.event_type_id in ^event_type_ids
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from simple_server_events in query,
      order_by: [asc: simple_server_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from simple_server_events in query,
      order_by: [desc: simple_server_events.name]
  end

  def order_by(query, "Newest first") do
    from simple_server_events in query,
      order_by: [desc: simple_server_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from simple_server_events in query,
      order_by: [asc: simple_server_events.inserted_at]
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
    from simple_server_events in query,
      left_join: event_types in assoc(simple_server_events, :event_type),
      preload: [event_type: event_types]
  end

  @spec _preload_users(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_users(query) do
    from simple_server_events in query,
      left_join: users in assoc(simple_server_events, :user),
      preload: [user: users]
  end
end
