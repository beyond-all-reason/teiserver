defmodule Teiserver.HookServer do
  use GenServer
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  # GenServer callbacks
  @impl true
  def handle_info(%{event: event, topic: "account_hooks", payload: payload}, state) do
    start_completed =
      ConCache.get(:application_metadata_cache, "teiserver_startup_completed") == true

    event = if start_completed, do: event, else: nil

    case event do
      nil ->
        nil

      "create_user" ->
        Teiserver.User.recache_user(int_parse(payload))

      "update_user" ->
        Teiserver.User.recache_user(int_parse(payload))

      "create_report" ->
        Teiserver.User.create_report(int_parse(payload))

      "update_report" ->
        Teiserver.User.update_report(int_parse(payload))

      _ ->
        throw("No HookServer account_hooks handler for event '#{event}'")
    end

    {:noreply, state}
  end

  def handle_info(%{event: event, topic: "application", payload: _payload}, state) do
    case event do
      "prep_stop" ->
        # Currently we don't do anything but we will
        # later want to tell each client everything is stopping for a
        # minute or two
        :ok

      _ ->
        throw("No HookServer application handler for event '#{event}'")
    end

    {:noreply, state}
  end

  @impl true
  def init(_) do
    if Application.get_env(:central, Teiserver)[:enable_hooks] do
      :ok = PubSub.subscribe(Central.PubSub, "account_hooks")
      :ok = PubSub.subscribe(Central.PubSub, "application")
    end
    {:ok, %{}}
  end
end
