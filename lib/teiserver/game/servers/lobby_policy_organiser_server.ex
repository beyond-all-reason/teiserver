defmodule Teiserver.Game.LobbyPolicyOrganiserServer do
  @moduledoc """
  There is one organiser and they each handle one lobby management config.
  """
  use GenServer
  require Logger

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    Logger.metadata([request_id: "LobbyPolicyOrganiserServer##{opts.lobby_policy.id}/#{opts.lobby_policy.name}"])

    # :ok = PubSub.subscribe(Central.PubSub, "teiserver_telemetry_client_events")

    state = %{
      db_policy: opts.lobby_policy
    }

    {:ok, state}
  end
end
