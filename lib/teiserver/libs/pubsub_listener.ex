defmodule Teiserver.Common.PubsubListener do
  @moduledoc """
  A genserver whose sole purpose is to listen to one or more pubusbs and record what they get sent

  Usage:
  ```
  # Create
  listener = PubsubListener.new_listener(["channel1", "channel2"])

  # Check mailbox
  messages = PubsubListener.get(listener)
  ```
  """

  use GenServer
  alias Phoenix.PubSub

  def new_listener(rooms) do
    {:ok, pid} = start_link(rooms)
    pid
  end

  def get(pid) do
    GenServer.call(pid, :get)
  end

  def start_link(rooms) do
    GenServer.start_link(__MODULE__, rooms, [])
  end

  # Internal
  defp subscribe_to_item(items) when is_list(items), do: Enum.each(items, &subscribe_to_item/1)

  defp subscribe_to_item(item) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "#{item}")
  end

  # GenServer callbacks
  def handle_cast({:subscribe, items}, state) do
    subscribe_to_item(items)
    {:noreply, state}
  end

  def handle_info(item, state) do
    {:noreply, [item | state]}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, []}
  end

  def init(rooms) do
    subscribe_to_item(rooms)
    {:ok, []}
  end
end
