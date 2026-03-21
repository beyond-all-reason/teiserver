defmodule Teiserver.Chat.RoomSupervisor do
  @moduledoc false
  alias Teiserver.Data.Types, as: T

  use DynamicSupervisor

  @spec start_room(String.t(), T.userid(), String.t(), String.t(), T.clan_id()) ::
          DynamicSupervisor.on_start_child()
  def start_room(room_name, author_id, topic, password, clan_id) do
    arg = %{
      name: room_name,
      author_id: author_id,
      topic: topic,
      password: password,
      clan_id: clan_id
    }

    DynamicSupervisor.start_child(
      __MODULE__,
      {Teiserver.Chat.RoomServer, arg}
    )
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end
