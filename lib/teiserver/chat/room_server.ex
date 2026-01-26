defmodule Teiserver.Chat.RoomServer do
  use GenServer, restart: :temporary

  alias Teiserver.Data.Types, as: T
  alias Teiserver.Chat
  require Logger

  @type room :: %{
          name: String.t(),
          members: MapSet.t(T.userid()),
          author_id: T.userid(),
          topic: String.t(),
          password: String.t(),
          clan_id: T.clan_id()
        }

  @typep state :: room()

  @spec get_room(String.t()) :: room() | nil
  def get_room(name) do
    GenServer.call(via_tuple(name), :get_room)
  catch
    :exit, {:noproc, _} -> nil
  end

  @spec join_room(String.t(), T.userid()) ::
          {:ok, :joined | :already_present} | {:error, :invalid_room}
  def join_room(name, user_id) do
    GenServer.call(via_tuple(name), {:join_room, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_room}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.name))
  end

  @impl true
  @spec init(term()) :: {:ok, state()}
  def init(args) do
    Logger.metadata(actor_type: :chat_room, actor_id: args.name)

    state = %{
      name: args.name,
      # not a fan of having to join after creation, but let's keep the same API
      members: MapSet.new(),
      author_id: args.author_id,
      topic: args.topic,
      password: args.password,
      clan_id: args.clan_id
    }

    update_member_count(state)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_room, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:join_room, userid}, _from, state) do
    if MapSet.member?(state.members, userid) do
      {:reply, {:ok, :already_present}, state}
    else
      state = Map.update!(state, :members, &MapSet.put(&1, userid))

      update_member_count(state)
      {:reply, {:ok, :joined}, state}
    end
  end

  defp update_member_count(state) do
    Chat.RoomRegistry.update_room(state.name, Enum.count(state.members))
  end

  def via_tuple(name) do
    Chat.RoomRegistry.via_tuple(name)
  end
end
