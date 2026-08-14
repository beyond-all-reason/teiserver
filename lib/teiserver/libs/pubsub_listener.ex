defmodule Teiserver.Common.PubsubListener do
  @moduledoc """
  A genserver whose sole purpose is to listen to one or more pubsubs and record what they get sent

  Usage:
  ```
  # Create
  listener = PubsubListener.new_listener(["channel1", "channel2"])

  # Check mailbox
  messages = PubsubListener.get(listener)
  ```

  The PubsubListener can also be used for debugging processes during a test, you can attach it to
  a pid and it will store the messages sent to that process. Given the structure of them you may
  want to use Enum.each to print them:
  ```
  messages = PubsubListener.get(listener)

  messages
  |> Enum.each(fn
    {:trace, _pid, _rec_or_send, m} ->
      IO.inspect m
  end)
  IO.puts length(messages)
  ```
  """

  alias Phoenix.PubSub

  use GenServer

  def new_listener(rooms) do
    {:ok, pid} = start_link(rooms)
    pid
  end

  def get(pid) do
    GenServer.call(pid, :get)
  end

  @doc """
  Given a PID it will trace all messages sent to that PID as if it was subscribed to them
  """
  def trace(listener_pid, pid_to_trace) do
    :erlang.trace(pid_to_trace, true, [
      :receive,
      {:tracer, listener_pid}
    ])
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
    # We prepend when building the list so need to reverse it here
    {:reply, Enum.reverse(state), []}
  end

  def init(rooms) do
    subscribe_to_item(rooms)
    {:ok, []}
  end
end
