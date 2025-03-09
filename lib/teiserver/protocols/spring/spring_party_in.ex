defmodule Teiserver.Protocols.Spring.PartyIn do
  require Logger

  alias Teiserver.Protocols.SpringOut
  alias Teiserver.Account
  alias Phoenix.PubSub

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("create_new_party", _, msg_id, state) when not is_nil(state.party_id) do
    # bit meh to do that in the protocol layer, but there isn't really another
    # place, and the whole thing is EOL
    SpringOut.reply(
      :no,
      {"c.party.create_new_party", "msg=Already in a party"},
      msg_id,
      state
    )
  end

  def do_handle("create_new_party", _, msg_id, state) do
    party = Account.create_party(state.user.id)

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_party:#{party.id}")

    state =
      SpringOut.reply(
        :okay,
        {"c.party.create_new_party", "party_id=#{party.id}"},
        msg_id,
        state |> Map.put(:party_id, party.id)
      )

    SpringOut.reply(:party, :member_added, {party.id, state.user.name}, message_id(), state)
  end

  def do_handle("invite_to_party", data, msg_id, state) do
    cmd_id = "c.party.invite_to_party"

    with [username] <- String.split(data) |> Enum.map(&String.trim/1),
         user when not is_nil(user) <- Teiserver.Account.get_user_by_name(username),
         # this check isn't great, it should be done in the party server
         # which is the source of truth for parties, but I'm taking a shortcut
         :ok <- if(state.party_id != nil, do: :ok, else: :not_in_party),
         :ok <- if(Account.client_exists?(user.id), do: :ok, else: :no_client) do
      Account.create_party_invite(state.party_id, user.id)

      SpringOut.reply(:okay, cmd_id, msg_id, state)
    else
      nil ->
        SpringOut.reply(:no, {cmd_id, "msg=no user found"}, msg_id, state)

      :not_in_party ->
        SpringOut.reply(:no, {cmd_id, "msg=cannot invite when not in party"}, msg_id, state)

      :no_client ->
        SpringOut.reply(:no, {cmd_id, "msg=user not connected"}, msg_id, state)

      _ ->
        SpringOut.reply(
          :no,
          {cmd_id, "msg=expected party_id username but could not parse"},
          msg_id,
          state
        )
    end
  end

  def do_handle("accept_invite_to_party", data, msg_id, state) do
    cmd_id = "c.party.accept_invite_to_party"

    with [party_id] <- String.split(data) |> Enum.map(&String.trim/1),
         {true, _party} <- Account.accept_party_invite(party_id, state.user.id) do
      SpringOut.reply(:okay, cmd_id, msg_id, Map.put(state, :party_id, party_id))
    else
      {false, reason} ->
        SpringOut.reply(:no, {cmd_id, "msg=#{reason}"}, msg_id, state)

      _ ->
        SpringOut.reply(
          :no,
          {cmd_id, "msg=expected party_id in argument but could not parse"},
          msg_id,
          state
        )
    end
  end

  def do_handle("decline_invite_to_party", data, msg_id, state) do
    cmd_id = "c.party.decline_invite_to_party"
    :ok = PubSub.unsubscribe(Teiserver.PubSub, "teiserver_party:#{state.party_id}")

    with [party_id] <- String.split(data) |> Enum.map(&String.trim/1) do
      Account.cancel_party_invite(party_id, state.user.id)
      SpringOut.reply(:okay, cmd_id, msg_id, state)
    else
      _ ->
        SpringOut.reply(
          :no,
          {cmd_id, "msg=expected party_id in argument but could not parse"},
          msg_id,
          state
        )
    end
  end

  def do_handle("leave_current_party", _data, msg_id, state) when is_nil(state.party_id),
    do:
      SpringOut.reply(
        :no,
        {"c.party.leave_current_party", "msg=not currently in a party"},
        msg_id,
        state
      )

  def do_handle("leave_current_party", _data, msg_id, state) do
    Account.leave_party(state.party_id, state.user.id)
    :ok = PubSub.unsubscribe(Teiserver.PubSub, "teiserver_party:#{state.party_id}")
    SpringOut.reply(:okay, "c.party.leave_current_party", msg_id, Map.put(state, :party_id, nil))
  end

  def do_handle("cancel_invite_to_party", data, msg_id, state) do
    cmd_id = "c.party.cancel_invite_to_party"

    with [username] <- String.split(data) |> Enum.map(&String.trim/1),
         user when not is_nil(user) <- Teiserver.Account.get_user_by_name(username),
         :ok <- if(state.party_id != nil, do: :ok, else: :not_in_party),
         :ok <- if(Account.client_exists?(user.id), do: :ok, else: :no_client) do
      party_id = state.party_id
      Account.cancel_party_invite(party_id, user.id)

      SpringOut.reply(:okay, cmd_id, msg_id, state)
    else
      nil ->
        SpringOut.reply(:no, {cmd_id, "msg=no user found"}, msg_id, state)

      :not_in_party ->
        SpringOut.reply(
          :no,
          {cmd_id, "msg=cannot cancel invite when not in party"},
          msg_id,
          state
        )

      :no_client ->
        SpringOut.reply(:no, {cmd_id, "msg=user not connected"}, msg_id, state)

      _ ->
        SpringOut.reply(
          :no,
          {cmd_id, "msg=expected username in argument but could not parse"},
          msg_id,
          state
        )
    end
  end

  def do_handle(msg, _, _msg_id, state) do
    Logger.debug("Unhandled party message: #{msg}")
    state
  end

  def handle_event(%{event: :party_invite, party_id: party_id, members: members}, state) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_party:#{party_id}")

    SpringOut.reply(:party, :invited_to_party, party_id, message_id(), state)

    # the web interface uses a list of parties to get the content. But with
    # chobby and spring, we need to let the client know about the members
    for uid <- members, username <- [Account.get_username_by_id(uid)], not is_nil(username) do
      SpringOut.reply(:party, :member_added, {party_id, username}, message_id(), state)
    end
  end

  def handle_event(%{event: :added_to_party, party_id: _party_id}, state) do
    # this event is redundant with others in term of communication with players, so just no-op it
    state
  end

  def handle_event(
        %{event: :updated_values, party_id: party_id, operation: {:member_added, userid}},
        state
      ) do
    case Teiserver.Account.get_user_by_id(userid) do
      nil -> state
      user -> SpringOut.reply(:party, :member_added, {party_id, user.name}, message_id(), state)
    end
  end

  def handle_event(
        %{event: :updated_values, party_id: party_id, operation: {:invite_cancelled, userid}},
        state
      ) do
    case Teiserver.Account.get_user_by_id(userid) do
      nil ->
        state

      user ->
        SpringOut.reply(:party, :invite_cancelled, {party_id, user.name}, message_id(), state)
    end
  end

  def handle_event(
        %{event: :updated_values, party_id: party_id, operation: {:member_removed, userid}},
        state
      ) do
    case Teiserver.Account.get_user_by_id(userid) do
      nil ->
        state

      user ->
        SpringOut.reply(:party, :member_removed, {party_id, user.name}, message_id(), state)
    end
  end

  def handle_event(%{event: :closed, party_id: party_id}, state) do
    # chobby would like to receive a member_left message when the last member leaves
    SpringOut.reply(:party, :member_removed, {party_id, state.user.name}, message_id(), state)
  end

  def handle_event(event, state) do
    Logger.debug("Unhandled party event: #{inspect(event)}")
    state
  end

  defp message_id() do
    "##{:rand.uniform(1_000_000)}"
  end
end
