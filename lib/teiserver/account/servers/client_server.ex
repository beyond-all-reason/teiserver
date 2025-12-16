defmodule Teiserver.Account.ClientServer do
  @moduledoc false
  use GenServer
  require Logger
  alias Teiserver.Lobby.ChatLib
  alias Phoenix.PubSub

  @impl true
  def handle_call(:get_client_state, _from, state) do
    {:reply, state.client, state}
  end

  def handle_call({:change_party, nil}, _from, %{client: %{party_id: nil}} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:change_party, party_id}, _from, state) do
    case state.client.party_id do
      nil ->
        :ok

      existing_id ->
        PubSub.broadcast(
          Teiserver.PubSub,
          "teiserver_client_messages:#{state.userid}",
          %{
            channel: "teiserver_client_messages:#{state.userid}",
            event: :left_party,
            party_id: existing_id
          }
        )

        PubSub.broadcast(
          Teiserver.PubSub,
          "teiserver_client_watch:#{state.userid}",
          %{
            channel: "teiserver_client_watch:#{state.userid}",
            event: :left_party,
            party_id: existing_id
          }
        )

        :ok
    end

    new_client = %{state.client | party_id: party_id}

    if party_id != nil do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{state.userid}",
        %{
          channel: "teiserver_client_messages:#{state.userid}",
          event: :added_to_party,
          party_id: party_id
        }
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_watch:#{state.userid}",
        %{
          channel: "teiserver_client_watch:#{state.userid}",
          event: :added_to_party,
          party_id: party_id
        }
      )
    end

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{state.userid}",
      %{
        channel: "teiserver_client_messages:#{state.userid}",
        event: :client_updated,
        userid: state.userid,
        client: new_client
      }
    )

    {:reply, :ok, %{state | client: new_client}}
  end

  @impl true
  def handle_cast({:update_values, partial_client}, state) do
    new_client = Map.merge(state.client, partial_client)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{state.userid}",
      %{
        channel: "teiserver_client_messages:#{state.userid}",
        event: :client_updated,
        userid: state.userid,
        client: new_client
      }
    )

    if state.client.lobby_id do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_updates:#{state.client.lobby_id}",
        %{
          channel: "teiserver_lobby_updates",
          event: :updated_client_battlestatus,
          lobby_id: state.client.lobby_id,
          userid: state.userid,
          client: partial_client
        }
      )
    end

    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_update_client, partial_client}, state) do
    Logger.warning(":merge_update_client is still being used, instead use :update_values")
    new_client = Map.merge(state.client, partial_client)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{state.userid}",
      %{
        channel: "teiserver_client_messages:#{state.userid}",
        event: :client_updated,
        userid: state.userid,
        client: partial_client
      }
    )

    if state.client.lobby_id do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_updates:#{state.client.lobby_id}",
        %{
          channel: "teiserver_lobby_updates",
          event: :updated_client_battlestatus,
          lobby_id: state.client.lobby_id,
          userid: state.userid,
          client: partial_client
        }
      )
    end

    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:update_client, new_client}, state) do
    if state.client.player != new_client.player and
         not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      if state.client.lobby_id do
        if new_client.player do
          ChatLib.persist_system_message(
            "#{state.client.name} became a player",
            state.client.lobby_id
          )
        else
          ChatLib.persist_system_message(
            "#{state.client.name} became a spectator",
            state.client.lobby_id
          )
        end
      end
    end

    new_client = Map.merge(state.client, new_client)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{state.userid}",
      %{
        channel: "teiserver_client_messages:#{state.userid}",
        event: :client_updated,
        userid: state.userid,
        client: new_client
      }
    )

    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:add_to_queue, queue_id}, state) do
    new_queues = [queue_id | state.client.queues] |> Enum.uniq()
    new_client = Map.merge(state.client, %{queues: new_queues})
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:remove_from_queue, queue_id}, state) do
    new_queues = state.client.queues |> List.delete(queue_id)
    new_client = Map.merge(state.client, %{queues: new_queues})
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast(:remove_from_all_queues, state) do
    new_client = Map.merge(state.client, %{queues: []})
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:update_tcp_pid, new_pid}, state) do
    new_client = Map.merge(state.client, %{tcp_pid: new_pid})
    {:noreply, %{state | client: new_client}}
  end

  @impl true
  def handle_info(:heartbeat, %{client: client_state} = state) do
    cond do
      client_state.tcp_pid == nil ->
        DynamicSupervisor.terminate_child(Teiserver.ClientSupervisor, self())

      Process.alive?(client_state.tcp_pid) == false ->
        DynamicSupervisor.terminate_child(Teiserver.ClientSupervisor, self())

      true ->
        :ok
    end

    {:noreply, state}
  end

  @spec start_link(list()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(%{client: %{userid: userid}} = state) do
    Logger.metadata(request_id: "ClientServer##{userid}")
    :timer.send_interval(6_000, :heartbeat)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ClientRegistry,
      userid,
      state.client.lobby_client
    )

    {:ok,
     Map.merge(state, %{
       userid: userid
     })}
  end
end
