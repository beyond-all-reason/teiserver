defmodule Teiserver.Protocols.Tachyon.V1.TachyonIn do
  require Logger
  alias Teiserver.Protocols.TachyonLib
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  alias Teiserver.Protocols.Tachyon.V1.{
    AuthIn,
    ClientIn,
    CommunicationIn,
    ConfigIn,
    LobbyHostIn,
    LobbyIn,
    MatchmakingIn,
    NewsIn,
    PartyIn,
    SystemIn,
    TelemetryIn,
    UserIn
  }

  @spec data_in(String.t(), map()) :: map()
  def data_in(data, state) do
    new_state =
      if String.ends_with?(data, "\n") do
        data = state.message_part <> data

        data
        |> String.split("\n")
        |> Enum.reduce(state, fn data, acc ->
          handle(data, acc)
        end)
        |> Map.put(:message_part, "")
      else
        %{state | message_part: state.message_part <> data}
      end

    new_state
  end

  @spec handle(String.t(), map) :: map
  def handle("", state), do: state
  def handle("\n", state), do: state
  def handle("\r\n", state), do: state

  def handle(raw_data, state) do
    clean_data =
      raw_data
      |> String.trim()

    case TachyonLib.decode(clean_data) do
      {:ok, data} ->
        dispatch(data["cmd"], data, state)

      {:error, error_type} ->
        reply(:system, :error, %{location: "decode", error: error_type}, state)
    end

    %{state | last_msg: System.system_time(:second)}
  end

  # If the data has a message id we add it to the state, saves us passing around
  # an extra value all the time and might help with debugging at some point
  @spec add_msg_id(map(), map()) :: map()
  defp add_msg_id(state, data) do
    new_msg_id =
      if Map.has_key?(data, "msg_id") do
        int_parse(data["msg_id"])
      end

    %{state | msg_id: new_msg_id}
  end

  @spec dispatch(String.t(), map(), map()) :: map()
  defp dispatch(nil, data, state) do
    reply(
      :system,
      :error,
      %{
        location: "dispatch",
        error: "cmd with nil value passed in with data '#{Kernel.inspect(data)}'"
      },
      state
    )
  end

  defp dispatch(cmd, data, state) do
    state =
      state
      |> add_msg_id(data)

    new_state =
      case String.split(cmd, ".") do
        ["c", namespace, subcommand] ->
          case namespace do
            "auth" ->
              AuthIn.do_handle(subcommand, data, state)

            "client" ->
              ClientIn.do_handle(subcommand, data, state)

            "communication" ->
              CommunicationIn.do_handle(subcommand, data, state)

            "config" ->
              ConfigIn.do_handle(subcommand, data, state)

            "lobby_host" ->
              LobbyHostIn.do_handle(subcommand, data, state)

            "lobby" ->
              LobbyIn.do_handle(subcommand, data, state)

            "matchmaking" ->
              MatchmakingIn.do_handle(subcommand, data, state)

            "news" ->
              NewsIn.do_handle(subcommand, data, state)

            "party" ->
              PartyIn.do_handle(subcommand, data, state)

            "system" ->
              SystemIn.do_handle(subcommand, data, state)

            "telemetry" ->
              TelemetryIn.do_handle(subcommand, data, state)

            "user" ->
              UserIn.do_handle(subcommand, data, state)

            _ ->
              reply(
                :system,
                :error,
                %{location: "dispatch", error: "No dispatch for namespace '#{namespace}'"},
                state
              )
          end

        _ ->
          reply(
            :system,
            :error,
            %{location: "parse", error: "Unable to parse cmd '#{cmd}'"},
            state
          )
      end

    # And remove the msg_id, don't want that bleeding over
    %{new_state | msg_id: nil}
  end
end
