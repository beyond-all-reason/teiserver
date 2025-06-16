defmodule Teiserver.Account.Party do
  @enforce_keys [:id, :leader, :members, :pending_invites]
  defstruct [
    :id,
    :leader,
    :members,
    :pending_invites
  ]
end

defmodule Teiserver.Account.PartyLib do
  # alias Phoenix.PubSub
  alias Teiserver.{Account, Chat, CacheUser}
  alias Teiserver.Account.Party
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  @spec colours() :: atom
  def colours, do: :primary2

  @spec icon() :: String.t()
  def icon, do: "fa-solid fa-user-group"

  @spec leader_name(T.party_id()) :: nil | String.t()
  def leader_name(party_id) do
    case get_party(party_id) do
      nil ->
        nil

      %{leader: leader} ->
        Account.get_username(leader)
    end
  end

  # Retrieval
  @spec get_party(nil) :: nil
  @spec get_party(T.party_id()) :: nil | T.party()
  def get_party(nil), do: nil

  def get_party(party_id) do
    call_party(party_id, :get_party)
  end

  @spec party_exists?(T.party_id()) :: boolean()
  def party_exists?(party_id) do
    case Horde.Registry.lookup(Teiserver.PartyRegistry, party_id) do
      [{_pid, _}] -> true
      _ -> false
    end
  end

  @spec list_party_ids() :: [T.party_id()]
  def list_party_ids() do
    Horde.Registry.select(Teiserver.PartyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @spec list_parties() :: [T.party()]
  def list_parties() do
    list_party_ids()
    |> list_parties()
  end

  @spec list_parties([T.party_id()]) :: [T.party()]
  def list_parties(id_list) do
    id_list
    |> Enum.map(fn c -> get_party(c) end)
  end

  # Create
  @spec create_party(T.userid()) :: T.party()
  def create_party(nil), do: nil

  def create_party(leader_id) do
    party = %Party{
      id: ExULID.ULID.generate(),
      leader: leader_id,
      members: [leader_id],
      pending_invites: []
    }

    start_party_server(party)
    party
  end

  # Members
  @spec create_party_invite(T.party_id(), T.userid()) :: :ok | nil
  def create_party_invite(party_id, userid) when is_integer(userid) do
    cast_party(party_id, {:create_invite, userid})
  end

  @spec cancel_party_invite(T.party_id(), T.userid()) :: :ok | nil
  def cancel_party_invite(party_id, userid) when is_integer(userid) do
    cast_party(party_id, {:cancel_invite, userid})
  end

  @spec accept_party_invite(T.party_id(), T.userid()) :: {true, map()} | {false, String.t()} | nil
  def accept_party_invite(party_id, userid) when is_integer(userid) do
    call_party(party_id, {:accept_invite, userid})
  end

  @spec leave_party(T.party_id(), T.userid()) :: :ok | nil
  def leave_party(party_id, userid) when is_integer(userid) do
    cast_party(party_id, {:member_leave, userid})
  end

  @spec kick_user_from_party(T.party_id(), T.userid()) :: :ok | nil
  def kick_user_from_party(party_id, userid) when is_integer(userid) do
    cast_party(party_id, {:kick_member, userid})
  end

  @spec move_user_to_party(T.party_id(), T.userid()) :: :ok | nil
  def move_user_to_party(party_id, userid) when is_integer(userid) do
    cast_party(party_id, {:add_member, userid})
  end

  # Process stuff
  @spec start_party_server(T.lobby()) :: pid()
  def start_party_server(party) do
    {:ok, server_pid} =
      DynamicSupervisor.start_child(Teiserver.PartySupervisor, {
        Teiserver.Account.PartyServer,
        name: "party_#{party.id}",
        data: %{
          party: party
        }
      })

    server_pid
  end

  @spec stop_party_server(T.party_id()) :: :ok | nil
  def stop_party_server(id) do
    case get_party_pid(id) do
      nil ->
        nil

      p ->
        DynamicSupervisor.terminate_child(Teiserver.PartySupervisor, p)
        :ok
    end
  end

  @spec get_party_pid(T.party_id()) :: pid() | nil
  def get_party_pid(party_id) do
    case Horde.Registry.lookup(Teiserver.PartyRegistry, party_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec cast_party(T.party_id(), any) :: any
  def cast_party(party_id, msg) do
    case get_party_pid(party_id) do
      nil -> nil
      pid -> GenServer.cast(pid, msg)
    end
  end

  @spec call_party(T.party_id(), any) :: any | nil
  def call_party(party_id, message) do
    case get_party_pid(party_id) do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, message)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @spec say(T.userid(), T.party_id(), String.t()) :: :ok | nil
  def say(userid, party_id, msg) do
    case party_exists?(party_id) do
      false -> nil
      true -> do_say(userid, party_id, msg)
    end
  end

  @spec do_say(T.userid(), T.party_id(), String.t()) :: :ok | nil
  defp do_say(userid, party_id, msg) do
    msg = trim_message(msg)
    user = Account.get_user_by_id(userid)

    allowed =
      cond do
        CacheUser.is_restricted?(user, ["All chat"]) -> false
        true -> true
      end

    if allowed do
      persist_message(userid, msg, party_id)

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_party:#{party_id}",
        %{
          channel: "teiserver_party:#{party_id}",
          event: :message,
          party_id: party_id,
          sender_id: userid,
          message: msg
        }
      )

      :ok
    else
      nil
    end
  end

  @spec persist_message(T.userid(), String.t(), T.party_id()) :: any
  def persist_message(userid, msg, party_id) do
    Chat.create_party_message(%{
      content: msg,
      party_id: party_id,
      inserted_at: Timex.now(),
      user_id: userid
    })
  end

  defp trim_message(msg) when is_list(msg) do
    Enum.join(msg, "\n") |> trim_message
  end

  defp trim_message(msg) do
    String.trim(msg)
  end
end
