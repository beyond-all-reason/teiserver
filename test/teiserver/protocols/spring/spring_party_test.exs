defmodule Teiserver.Protocols.Spring.SpringPartyTest do
  use Teiserver.ServerCase, async: false
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Account.PartyLib

  alias Teiserver.Support.Polling

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_until: 1]

  defp setup_user(_context) do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  describe "create" do
    setup [:setup_user]

    test "create", %{socket: socket} do
      assert create_party!(socket) != nil
    end

    test "cannot create when in a party", %{socket: socket} do
      create_party!(socket)
      create_party(socket)
      assert {"NO", _, _} = _recv_until(socket) |> parse_in_message()
    end

    test "create from web", %{socket: socket, user: user} do
      party = Teiserver.Account.create_party(user.id)

      assert {"s.party.joined_party", [party_id, username], _} =
               _recv_until(socket) |> parse_in_message()

      assert party_id == party.id
      assert username == user.name
    end
  end

  describe "invite" do
    setup do
      {:ok, socket: socket1, user: user1} = setup_user(nil)
      {:ok, socket: socket2, user: user2} = setup_user(nil)
      # absorb the broadcasted message that another player is online
      "ADDUSER " <> _ = _recv_until(socket1)
      {:ok, socket1: socket1, user1: user1, socket2: socket2, user2: user2}
    end

    test "online player", %{socket1: sock1, socket2: sock2, user2: user2} = ctx do
      party_id = create_party!(sock1)
      invite_to_party!(sock1, user2.name)

      [ok, joined] = _recv_until(sock2) |> parse_in_messages()
      assert {"s.party.invited_to_party", [^party_id, _], _} = ok
      assert {"s.party.joined_party", [^party_id, username1], _} = joined
      assert username1 == ctx.user1.name
    end

    test "invalid player", %{socket1: sock1} do
      create_party!(sock1)
      invite_to_party(sock1, "lolnope-this-is-not-a-username-for-party")

      assert {"NO", _, _} = _recv_until(sock1) |> parse_in_message()
    end

    test "offline player", %{socket1: sock1, user2: user2} do
      Teiserver.Client.disconnect(user2.id)
      assert "REMOVEUSER " <> _ = _recv_until(sock1)
      create_party!(sock1)
      invite_to_party(sock1, user2.name)

      assert {"NO", %{"msg" => "user not connected"}, _} =
               _recv_until(sock1) |> parse_in_message()
    end
  end

  describe "handle invite" do
    setup do
      {:ok, socket: socket1, user: user1} = setup_user(nil)
      {:ok, socket: socket2, user: user2} = setup_user(nil)

      # absorb the broadcasted message that another player is online
      "ADDUSER " <> _ = _recv_until(socket1)

      party_id = create_party!(socket1)
      invite_to_party!(socket1, user2.name)

      # absorb the message and the "added_to_party" message. Assume this
      # works as it is tested in another test
      _recv_until(socket2)

      {:ok, socket1: socket1, user1: user1, socket2: socket2, user2: user2, party_id: party_id}
    end

    test "accept invite", %{socket1: sock1, user2: user2, socket2: sock2, party_id: party_id} do
      accept_invite!(sock2, party_id)

      assert {"s.party.joined_party", [^party_id, username2], _} =
               _recv_until(sock1) |> parse_in_message()

      assert username2 == user2.name
    end

    test "must be in party", ctx do
      invite_to_party(ctx.socket2, ctx.user1.name)
      assert {"NO", _, _} = _recv_until(ctx.socket2) |> parse_in_message()
    end

    test "decline invite", %{socket1: sock1, user2: user2, socket2: sock2, party_id: party_id} do
      decline_invite!(sock2, party_id)

      assert {"s.party.invite_cancelled", [^party_id, username2], _} =
               _recv_until(sock1) |> parse_in_message()

      assert username2 == user2.name

      # the invite is now invalid
      accept_invite(sock2, party_id)
      assert {"NO", _, _} = _recv_until(sock2) |> parse_in_message()
    end

    test "cancel invite, bad user", ctx do
      cancel_invite(ctx.socket1, "definitely-not-a-valid-username")
      assert {"NO", _, _} = _recv_until(ctx.socket1) |> parse_in_message()
    end

    test "must be in party to cancel invite", ctx do
      cancel_invite(ctx.socket2, ctx.user2.name)
      assert {"NO", _, _} = _recv_until(ctx.socket2) |> parse_in_message()
    end

    test "cancel invite", ctx do
      username2 = ctx.user2.name
      party_id = ctx.party_id
      _recv_until(ctx.socket2)
      cancel_invite!(ctx.socket1, username2)

      cancelled = _recv_until(ctx.socket2) |> parse_in_message()
      assert {"s.party.invite_cancelled", [^party_id, ^username2], _} = cancelled

      invite_to_party!(ctx.socket1, username2)
      [invited, joined] = _recv_until(ctx.socket2) |> parse_in_messages()
      assert {"s.party.invited_to_party", _, _} = invited
      assert {"s.party.joined_party", _, _} = joined
    end

    test "cancel invite via web", ctx do
      username2 = ctx.user2.name
      Teiserver.Account.cancel_party_invite(ctx.party_id, ctx.user2.id)

      party_id = ctx.party_id

      assert {"s.party.invite_cancelled", [^party_id, ^username2], _} =
               _recv_until(ctx.socket2) |> parse_in_message()
    end
  end

  describe "leaving parties" do
    setup do
      {:ok, socket: socket1, user: user1} = setup_user(nil)
      {:ok, socket: socket2, user: user2} = setup_user(nil)

      # absorb the broadcasted message that another player is online
      "ADDUSER " <> _ = _recv_until(socket1)

      party_id = create_party!(socket1)
      invite_to_party!(socket1, user2.name)
      # absorb the message and the "added_to_party" message. Assume this
      # works as it is tested in another test
      _recv_until(socket2)

      accept_invite!(socket2, party_id)

      assert {"s.party.joined_party", [^party_id, _], _} =
               _recv_until(socket1) |> parse_in_message()

      {:ok, socket1: socket1, user1: user1, socket2: socket2, user2: user2, party_id: party_id}
    end

    # https://github.com/beyond-all-reason/teiserver/actions/runs/19192835180/job/54869643283
    @tag :needs_attention
    test "leave party", %{socket1: sock1, user2: user2, socket2: sock2, party_id: party_id} do
      leave_party!(sock2)

      assert {"s.party.left_party", [^party_id, username], _} =
               _recv_until(sock1) |> parse_in_message()

      assert username == user2.name
    end

    test "can create party after leaving", %{socket1: sock1} do
      leave_party!(sock1)
      create_party!(sock1)
    end

    test "leave party via web", ctx do
      Teiserver.Account.leave_party(ctx.party_id, ctx.user2.id)
      party_id = ctx.party_id
      user1 = ctx.user1.name
      user2 = ctx.user2.name

      assert {"s.party.left_party", [^party_id, ^user2], _} =
               _recv_until(ctx.socket1) |> parse_in_message()

      assert {"s.party.left_party", [^party_id, ^user2], _} =
               _recv_until(ctx.socket2) |> parse_in_message()

      Teiserver.Account.leave_party(ctx.party_id, ctx.user1.id)

      assert {"s.party.left_party", [^party_id, ^user1], _} =
               _recv_until(ctx.socket1) |> parse_in_message()
    end
  end

  # https://github.com/beyond-all-reason/teiserver/actions/runs/18627831079/job/53108311559?pr=831
  @tag :needs_attention
  test "both in parties" do
    {:ok, socket: socket1, user: user1} = setup_user(nil)
    {:ok, socket: socket2, user: user2} = setup_user(nil)
    # absorb the broadcasted message that another player is online
    "ADDUSER " <> _ = _recv_until(socket1)

    username1 = user1.name
    username2 = user2.name

    party1 = create_party!(socket1)
    create_party!(socket2)
    invite_to_party!(socket1, user2.name)
    [invited, joined] = _recv_until(socket2) |> parse_in_messages()
    assert {"s.party.invited_to_party", [^party1, ^username2], _} = invited
    assert {"s.party.joined_party", [^party1, ^username1], _} = joined
    leave_party!(socket1)

    [cancelled, left] = _recv_until(socket2) |> parse_in_messages()

    assert {"s.party.invite_cancelled", [^party1, ^username2], _} = cancelled
    assert {"s.party.left_party", [^party1, ^username1], _} = left
    assert {"s.party.invite_cancelled", [^party1, ^username2], _} = cancelled
  end

  test "with 3 players" do
    # only test happy paths, but with more players to check broadcast mechanics
    {:ok, socket: socket1, user: user1} = setup_user(nil)
    {:ok, socket: socket2, user: user2} = setup_user(nil)
    {:ok, socket: socket3, user: user3} = setup_user(nil)

    username1 = user1.name
    username2 = user2.name
    username3 = user3.name

    # absorb the broadcasted message that another player is online
    _recv_until(socket1)
    _recv_until(socket2)

    party_id = create_party!(socket1)

    # invite both players
    invite_to_party!(socket1, user2.name)

    assert [{"s.party.invited_to_party", _, _}, {"s.party.joined_party", _, _}] =
             _recv_until(socket2) |> parse_in_messages()

    invite_to_party!(socket1, user3.name)

    assert [{"s.party.invited_to_party", _, _}] =
             _recv_until(socket2) |> parse_in_messages()

    assert [
             {"s.party.invited_to_party", _, _},
             {"s.party.joined_party", _, _},
             # also get the message about user2 being invited
             {"s.party.invited_to_party", [_, ^username2], _}
           ] =
             _recv_until(socket3) |> parse_in_messages()

    # player 3 accepts the invite
    accept_invite!(socket3, party_id)

    assert [{"s.party.joined_party", [_, ^username3], _}] =
             _recv_until(socket1) |> parse_in_messages()

    assert [{"s.party.joined_party", [_, ^username3], _}] =
             _recv_until(socket2) |> parse_in_messages()

    accept_invite!(socket2, party_id)

    assert [{"s.party.joined_party", [_, ^username2], _}] =
             _recv_until(socket1) |> parse_in_messages()

    assert [{"s.party.joined_party", [_, ^username2], _}] =
             _recv_until(socket3) |> parse_in_messages()

    # check disconnection triggers "left party" to all members
    Teiserver.Client.disconnect(user1.id)

    assert [{"s.party.left_party", [_, ^username1], _}, _] =
             _recv_until(socket2) |> parse_in_messages()

    assert [{"s.party.left_party", [_, ^username1], _}, _] =
             _recv_until(socket3) |> parse_in_messages()
  end

  defp create_party(socket) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.create_new_party\n")
  end

  defp create_party!(socket) do
    create_party(socket)

    [ok, joined] = _recv_until(socket) |> parse_in_messages()

    assert {"OK", %{"party_id" => party_id}, _} = ok
    assert {"s.party.joined_party", [^party_id, _], _} = joined

    Polling.poll_until_some(fn ->
      PartyLib.get_party(party_id)
    end)

    party_id
  end

  defp invite_to_party(socket, username) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.invite_to_party #{username}\n")
  end

  defp invite_to_party!(socket, username) do
    invite_to_party(socket, username)
    [ok, invited] = _recv_until(socket) |> parse_in_messages()
    assert {"OK", _, _} = ok
    assert {"s.party.invited_to_party", [_, ^username], _} = invited
  end

  defp accept_invite(socket, party_id) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.accept_invite_to_party #{party_id}\n")
  end

  defp accept_invite!(socket, party_id) do
    accept_invite(socket, party_id)
    [ok, joined] = _recv_until(socket) |> parse_in_messages()
    assert {"OK", _, _} = ok
    assert {"s.party.joined_party", [^party_id, _], _} = joined
  end

  defp decline_invite(socket, party_id) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.decline_invite_to_party #{party_id}\n")
  end

  defp decline_invite!(socket, party_id) do
    decline_invite(socket, party_id)
    [ok, cancelled] = _recv_until(socket) |> parse_in_messages()
    assert {"OK", _, _} = ok
    assert {"s.party.invite_cancelled", [^party_id, _], _} = cancelled
  end

  defp cancel_invite(socket, username) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.cancel_invite_to_party #{username}\n")
  end

  defp cancel_invite!(socket, username) do
    cancel_invite(socket, username)

    [ok, cancelled] = _recv_until(socket) |> parse_in_messages()
    assert {"OK", _, _} = ok
    assert {"s.party.invite_cancelled", _, _} = cancelled
  end

  defp leave_party(socket) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.leave_current_party\n")
  end

  defp leave_party!(socket) do
    leave_party(socket)
    assert {"OK", _, _} = _recv_until(socket) |> parse_in_message()
  end

  defp parse_in_messages(raw) do
    String.split(raw, "\n") |> Enum.reject(&(&1 == "")) |> Enum.map(&parse_in_message/1)
  end

  defp parse_in_message(raw) do
    case SpringIn.parse_in_message(raw) do
      nil -> nil
      {cmd, args, ""} -> parse_args(nil, cmd, args)
      {cmd, args, msg_id} -> parse_args(msg_id, cmd, args)
    end
  end

  defp parse_args(msg_id, cmd, raw_args) when cmd in ["NO", "OK"] do
    args =
      String.split(raw_args, "\t")
      |> Enum.reduce(%{}, fn frag, m ->
        [k, v] = String.split(frag, "=")
        Map.put(m, String.trim(k), String.trim(v))
      end)

    {cmd, args, msg_id}
  end

  defp parse_args(msg_id, cmd, raw_args) do
    args = String.split(raw_args) |> Enum.map(&String.trim/1)
    {cmd, args, msg_id}
  end
end
