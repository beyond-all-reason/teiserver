defmodule Teiserver.Account.AccoladeChatServer do
  @moduledoc """
  Each chat server is for a specific user, when the chat server has done it's job it self-terminates.
  """

  use GenServer
  alias Teiserver.{User, Account}
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Data.Types, as: T

  @line_break "-------------------------------------------------"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec empty_state(T.userid(), T.userid()) :: map()
  def empty_state(userid, recipient_id) do
    badge_types = AccoladeLib.get_badge_types()

    %{
      bot_id: AccoladeLib.get_accolade_bot_userid(),
      badge_types: badge_types,
      userid: userid,
      user: User.get_user_by_id(userid),
      recipient_id: recipient_id,
      recipient: User.get_user_by_id(recipient_id),

      stage: :not_started
    }
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    new_state = do_tick(state)
    {:noreply, new_state}
  end

  # Handling user messages
  def handle_info({:user_message, message}, %{stage: :awaiting_choice} = state) do
    new_state = case Integer.parse(String.trim(message)) do
      {0, _} ->
        User.send_direct_message(state.bot_id, state.userid, "Thank you for your feedback, no Accolade will be bestowed.")
        send(self(), :terminate)
        %{state | stage: :completed}

      {choice, _} ->
        badge_type = state.badge_types
        |> Enum.filter(fn {i, _} -> i == choice end)

        case badge_type do
          [] ->
            User.send_direct_message(state.bot_id, state.userid, "None of the listed Accolades match that option")
            state

          [{_, selected_type}] ->
            Account.create_accolade(%{
              recipient_id: state.recipient_id,
              giver_id: state.userid,
              badge_type_id: selected_type.id,
              inserted_at: Timex.now()
            })

            User.send_direct_message(state.bot_id, state.userid, "Thank you for your feedback, this Accolade will be bestowed.")
            send(self(), :terminate)
            %{state | stage: :completed}
        end
      :error ->
        User.send_direct_message(state.bot_id, state.userid, "I'm sorry but I can't pick an Accolade based on that value")
        state
    end
    {:noreply, new_state}
  end

  def handle_info(:terminate, state) do
    ConCache.delete(:teiserver_accolade_pids, state.userid)
    DynamicSupervisor.terminate_child(Teiserver.Account.AccoladeSupervisor, self())
    {:stop, :normal, %{state | userid: nil}}
  end

  def terminate(_reason, state) do
    ConCache.delete(:teiserver_accolade_pids, state.userid)
  end

  @spec do_tick(map()) :: map()
  defp do_tick(state) do
    case state.stage do
      :not_started -> send_initial_message(state)
    end
  end


  @spec send_initial_message(map()) :: map()
  defp send_initial_message(state) do
    badge_lines = state.badge_types
    |> Enum.map(fn {i, bt} -> "#{i} - #{bt.name}, #{bt.description}" end)

    User.send_direct_message(state.bot_id, state.userid, [
      @line_break,
      "You have an opportunity to leave feedback on one of the players in your last game. We have selected #{state.recipient.name}",
      "Which of the following accolades do you feel they most deserve (if any)?",
      "0 - No accolade",
    ] ++ badge_lines ++ [
      ".",
      "Reply to this message with the number corresponding to the Accolade you feel is most appropriate for this player for this match."
    ])

    %{state | stage: :awaiting_choice}
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    userid = opts[:userid]
    recipient_id = opts[:recipient_id]

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_accolade_pids, userid, self())
    # :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(userid, recipient_id)}
  end
end
