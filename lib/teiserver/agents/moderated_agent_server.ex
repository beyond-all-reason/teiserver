defmodule Teiserver.Agents.ModeratedAgentServer do
  use GenServer
  alias Central.Account
  alias Teiserver.Coordinator
  alias Teiserver.Agents.AgentLib
  require Logger

  @tick_period 3000
  @logout_chance 1
  @login_chance 1

  def handle_info(:startup, state) do
    name = "Moderated_#{state.number}"

    # It's possible the user doesn't exist so we need to
    # login to ensure it does and we can then create
    # a report for it
    socket = AgentLib.get_socket()
    {:success, user} = AgentLib.login(socket, %{
      name: name,
      email: "Moderated_#{state.number}@agents",
      extra_data: %{}
    })

    # Immediately log out
    AgentLib._send(socket, %{cmd: "c.auth.disconnect"})

    # Create the report
    case Account.list_reports(search: [target_id: user.id]) do
      [] ->
        create_report(user, state.action)
      _ ->
        :ok
    end

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket, name: name, user: user}}
  end

  def handle_info(:tick, %{logged_in: true} = state) do
    state = if :rand.uniform() <= @logout_chance do
      do_logout(state)
    else
      state
    end

    {:noreply, state}
  end

  def handle_info(:tick, %{logged_in: false} = state) do
    state = if :rand.uniform() <= @login_chance do
      do_login(state)
    else
      state
    end

    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = data
    |> AgentLib.translate
    |> Enum.reduce(state, fn data, acc ->
      handle_msg(data, acc)
    end)

    {:noreply, new_state}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    {:noreply, %{state | logged_in: false, socket: nil}}
  end

  defp do_login(state) do
    socket = AgentLib.get_socket()

    {:success, user} = AgentLib.login(socket, %{
      name: state.name,
      email: "Moderated_#{state.number}@agents",
      extra_data: %{}
    })

    # Reset flood protection
    Central.cache_put(:teiserver_login_count, user.id, 0)

    %{state | socket: socket, logged_in: true}
  end

  defp do_logout(state) do
    AgentLib._send(state.socket, %{cmd: "c.auth.disconnect"})
    %{state | logged_in: false}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.system.pong"}, state) do
    state
  end
  defp handle_msg(%{"cmd" => "s.communication.received_direct_message"}, state) do
    state
  end

  defp create_report(user, "Warning") do
    {:ok, _report} = Account.create_report(%{
      "location" => "web-admin-instant",
      "location_id" => nil,
      "reason" => "Agent mode test",
      "reporter_id" => Coordinator.get_coordinator_userid(),
      "target_id" => user.id,
      "response_text" => "Agent mode test",
      "response_action" => "Restrict",
      "responded_at" => Timex.now(),
      "followup" => "",
      "code_references" => [],
      "expires" => nil,
      "responder_id" => Coordinator.get_coordinator_userid(),
      "action_data" => %{
        "restriction_list" => ["Warning reminder"]
      }
    })
  end

  defp create_report(user, "Mute") do
    {:ok, _report} = Account.create_report(%{
      "location" => "web-admin-instant",
      "location_id" => nil,
      "reason" => "Agent mode test",
      "reporter_id" => Coordinator.get_coordinator_userid(),
      "target_id" => user.id,
      "response_text" => "Agent mode test",
      "response_action" => "Restrict",
      "responded_at" => Timex.now(),
      "followup" => "",
      "code_references" => [],
      "expires" => nil,
      "responder_id" => Coordinator.get_coordinator_userid(),
      "action_data" => %{
        "restriction_list" => ["All chat"]
      }
    })
  end

  defp create_report(user, "Ban") do
    {:ok, _report} = Account.create_report(%{
      "location" => "web-admin-instant",
      "location_id" => nil,
      "reason" => "Agent mode test",
      "reporter_id" => Coordinator.get_coordinator_userid(),
      "target_id" => user.id,
      "response_text" => "Agent mode test",
      "response_action" => "Restrict",
      "responded_at" => Timex.now(),
      "followup" => "",
      "code_references" => [],
      "expires" => nil,
      "responder_id" => Coordinator.get_coordinator_userid(),
      "action_data" => %{
        "restriction_list" => ["Login", "Site"]
      }
    })
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  def init(opts) do
    send(self(), :startup)

    {:ok,
     %{
       id: opts.id,
       number: opts.number,
       logged_in: false,
       action: opts[:action],
       name: nil,
       user: nil,
       socket: nil
     }}
  end
end
