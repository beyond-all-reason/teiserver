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
    case event do
      "create_user" ->
        Teiserver.User.recache_user(int_parse(payload))

      "update_user" ->
        Teiserver.User.recache_user(int_parse(payload))

      "update_report" ->
        Teiserver.User.new_report(int_parse(payload))

      _ ->
        throw("No HookServer account_hooks handler for event '#{event}'")
    end

    {:noreply, state}
  end

  @impl true
  def init(_) do
    :ok = PubSub.subscribe(Central.PubSub, "account_hooks")
    {:ok, %{}}
  end
end
