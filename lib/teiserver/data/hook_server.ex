defmodule Barserver.HookServer do
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
        if Barserver.Communication.use_discord?() do
          Barserver.Bridge.DiscordBridgeBot.new_report(data.report)
        end

      :updated_report ->
        :ok

      :new_action ->
        Barserver.Moderation.RefreshUserRestrictionsTask.refresh_user(data.action.target_id)

      :updated_action ->
        Barserver.Moderation.RefreshUserRestrictionsTask.refresh_user(data.action.target_id)

      :new_response ->
        :ok

      :updated_response ->
        :ok

      :new_proposal ->
        :ok

      :updated_proposal ->
        :ok

      :new_ban ->
        :ok

      event ->
        Logger.error(
          "Error at: #{__ENV__.file}:#{__ENV__.line} - No handler for event '#{event}'"
        )

        :ok
    end

    {:noreply, state}
  end

  def handle_info({:account_hooks, event, payload, _reason}, state) do
    start_completed =
      Barserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") == true

    event = if start_completed, do: event, else: nil

    case event do
      nil ->
        nil

      :create_user ->
        Barserver.CacheUser.recache_user(payload.id)

      :update_user ->
        Barserver.CacheUser.recache_user(payload.id)

      :create_report ->
        :ok

      :update_report ->
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
          Barserver.PubSub,
          "teiserver_server",
          %{
            channel: "teiserver_server",
            event: :prep_stop,
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
    if Application.get_env(:teiserver, Barserver)[:enable_hooks] do
      :ok = PubSub.subscribe(Barserver.PubSub, "account_hooks")
      :ok = PubSub.subscribe(Barserver.PubSub, "global_moderation")
      :ok = PubSub.subscribe(Barserver.PubSub, "application")
    end

    {:ok, %{}}
  end
end
