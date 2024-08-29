defmodule Teiserver.Account.AccoladeChatServer do
  @moduledoc """
  Each chat server is for a specific user, when the chat server has done it's job it self-terminates.
  """

  use GenServer
  alias Teiserver.Config
  alias Teiserver.{CacheUser, Account}
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Account.AccoladeBotServer
  alias Teiserver.Data.Types, as: T

  @line_break "-------------------------------------------------"
  @chat_timeout 600_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec empty_state(T.userid(), T.userid(), T.lobby_id()) :: map()
  def empty_state(userid, recipient_id, match_id) do
    badge_types = AccoladeLib.get_badge_types()

    %{
      bot_id: AccoladeLib.get_accolade_bot_userid(),
      badge_types: badge_types,
      userid: userid,
      user: Account.get_user_by_id(userid),
      recipient_id: recipient_id,
      recipient: Account.get_user_by_id(recipient_id),
      match_id: match_id,
      stage: :not_started
    }
  end

  def handle_call(:ping, _from, state) do
    {:reply, :ok, state}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    new_state = do_tick(state)
    :timer.send_after(@chat_timeout, :self_terminate)
    {:noreply, new_state}
  end

  # Handling user messages
  def handle_info({:user_message, message}, %{stage: :awaiting_choice} = state) do
    integer_choice =
      case Integer.parse(String.trim(message)) do
        :error -> :error
        {v, _} -> v
      end

    new_state =
      cond do
        String.downcase(message) == "n" ->
          Account.create_accolade(%{
            recipient_id: state.recipient_id,
            giver_id: state.userid,
            match_id: state.match_id,
            inserted_at: Timex.now()
          })

          increment_miss_count(state.userid, 3)

          CacheUser.send_direct_message(
            state.bot_id,
            state.userid,
            "Thank you for your feedback, no Accolade will be bestowed."
          )

          send(self(), :terminate)
          %{state | stage: :completed}

        integer_choice == 0 ->
          increment_miss_count(state.userid, 3)

          CacheUser.send_direct_message(
            state.bot_id,
            state.userid,
            "Thank you for your feedback, no Accolade will be bestowed."
          )

          send(self(), :terminate)
          %{state | stage: :completed}

        integer_choice != :error ->
          badge_type =
            state.badge_types
            |> Enum.filter(fn {i, _} -> i == integer_choice end)

          case badge_type do
            [] ->
              CacheUser.send_direct_message(
                state.bot_id,
                state.userid,
                "None of the listed Accolades match that option"
              )

              state

            [{_, selected_type}] ->
              Account.create_accolade(%{
                recipient_id: state.recipient_id,
                giver_id: state.userid,
                badge_type_id: selected_type.id,
                match_id: state.match_id,
                inserted_at: Timex.now()
              })

              if Config.get_site_config_cache("teiserver.Inform of new accolades") do
                bot_pid = AccoladeLib.get_accolade_bot_pid()
                :timer.send_after(30_000, bot_pid, {:new_accolade, state.recipient_id})
              end

              decrement_miss_count(state.userid, 5)

              CacheUser.send_direct_message(
                state.bot_id,
                state.userid,
                "Thank you for your feedback, this Accolade will be bestowed."
              )

              send(self(), :terminate)
              %{state | stage: :completed}
          end

        :error ->
          CacheUser.send_direct_message(
            state.bot_id,
            state.userid,
            "I'm sorry but I can't pick an Accolade based on that value"
          )

          state
      end

    {:noreply, new_state}
  end

  def handle_info(:self_terminate, state) do
    increment_miss_count(state.userid, 10)

    send(self(), :terminate)
    {:noreply, state}
  end

  def handle_info(:terminate, state) do
    DynamicSupervisor.terminate_child(Teiserver.Account.AccoladeSupervisor, self())
    {:stop, :normal, %{state | userid: nil}}
  end

  def terminate(_reason, _state) do
    :ok
  end

  @spec do_tick(map()) :: map()
  defp do_tick(state) do
    case state.stage do
      :not_started -> send_initial_message(state)
    end
  end

  defp decrement_miss_count(userid, amount) do
    stats = Account.get_user_stat_data(userid)
    accolade_miss_count = Map.get(stats, "accolade_miss_count", 0)

    Account.update_user_stat(userid, %{
      "accolade_miss_count" => max(accolade_miss_count - amount, 0)
    })
  end

  defp increment_miss_count(userid, amount) do
    stats = Account.get_user_stat_data(userid)
    accolade_miss_count = Map.get(stats, "accolade_miss_count", 0)

    Account.update_user_stat(userid, %{
      "accolade_miss_count" =>
        min(max(accolade_miss_count + amount, 0), AccoladeBotServer.max_miss_count())
    })
  end

  @spec send_initial_message(map()) :: map()
  defp send_initial_message(state) do
    badge_lines =
      state.badge_types
      |> Enum.map(fn {i, bt} -> "#{i} - #{bt.name}, #{bt.description}" end)

    CacheUser.send_direct_message(
      state.bot_id,
      state.userid,
      [
        @line_break,
        "You have an opportunity to leave feedback on one of the players in your last game. We have selected #{state.recipient.name}",
        "Which of the following accolades do you feel they most deserve (if any)?",
        "N - No accolade for this player at all",
        "0 - No accolade this time, ask again later"
      ] ++
        badge_lines ++
        [
          ".",
          "Reply to this message with the number corresponding to the Accolade you feel is most appropriate for this player for this match."
        ]
    )

    %{state | stage: :awaiting_choice}
  end

  @spec init(map()) :: {:ok, map()}
  def init(opts) do
    userid = opts[:userid]
    recipient_id = opts[:recipient_id]
    match_id = opts[:match_id]

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.AccoladesRegistry,
      "AccoladeChatServer:#{userid}",
      userid
    )

    # :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(userid, recipient_id, match_id)}
  end
end
