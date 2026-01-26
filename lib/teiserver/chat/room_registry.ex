defmodule Teiserver.Chat.RoomRegistry do
  @moduledoc """
  A registry for the various chat rooms
  """

  def start_link() do
    Registry.start_link(name: __MODULE__, keys: :unique)
  end

  def child_spec(_) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  @doc """
  How to reach a given chat room
  """
  @spec via_tuple(String.t()) :: GenServer.name()
  def via_tuple(room_name) do
    {:via, Registry, {__MODULE__, room_name}}
  end

  @doc """
  Update the number of member
  """
  def update_room(room_name, member_count) do
    {_, _} = Registry.update_value(__MODULE__, room_name, fn _ -> member_count end)
    :ok
  end

  @spec list_rooms() :: [{String.t(), member_count :: non_neg_integer()}]
  def list_rooms() do
    Registry.select(__MODULE__, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end
end
