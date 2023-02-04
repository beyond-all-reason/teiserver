defmodule Teiserver.HookServer do
  use GenServer
  alias Phoenix.PubSub
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def handle_info(%{channel: "global_moderation"} = data, state) do
    case data.event do
      :new_report ->
        Teiserver.Bridge.DiscordBridge.new_report(data.report)

      :new_action ->
        Teiserver.Bridge.DiscordBridge.new_action(data.action)
        Teiserver.User.new_moderation_action(data.action)
        :ok

      :updated_action ->
        Teiserver.User.updated_moderation_action(data.action)
        :ok

      :new_proposal ->
        :ok

      :updated_proposal ->
        :ok

      :new_ban ->
        :ok

      event ->
        Logger.error("Error at: #{__ENV__.file}:#{__ENV__.line} - No handler for event '#{event}'")
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:account_hooks, event, payload, _reason}, state) do
    start_completed =
      Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") == true

    event = if start_completed, do: event, else: nil

    case event do
      nil ->
        nil

      :create_user ->
        Teiserver.User.recache_user(payload.id)

      :update_user ->
        Teiserver.User.recache_user(payload.id)

      :create_report ->
        # Coordinator.create_report(payload)
        # Teiserver.Bridge.DiscordBridge.create_report(payload)
        # Teiserver.User.create_report(payload, reason)
        :ok

      :update_report ->
        # Coordinator.update_report(payload, reason)
        # Teiserver.Bridge.DiscordBridge.report_updated(payload, reason)
        # Teiserver.User.update_report(payload, reason)
        :ok

      _ ->
        throw("No HookServer account_hooks handler for event '#{event}'")
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "application", event: app_event}, state) do
    case app_event do
      :started ->
        :ok

      :prep_stop ->
        # Currently we don't do anything but we will
        # later want to tell each client everything is stopping for a
        # minute or two
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_server",
          %{
            channel: "teiserver_server",
            event: "stop",
            node: Node.self()
          }
        )
        :ok

      _ ->
        throw("No HookServer application handler for event '#{app_event}'")
    end

    {:noreply, state}
  end

  @impl true
  @spec init(any) :: {:ok, %{}}
  def init(_) do
    if Application.get_env(:central, Teiserver)[:enable_hooks] do
      :ok = PubSub.subscribe(Central.PubSub, "account_hooks")
      :ok = PubSub.subscribe(Central.PubSub, "global_moderation")
      :ok = PubSub.subscribe(Central.PubSub, "application")
    end
    {:ok, %{}}
  end
end
