defmodule Teiserver.Protocols.Tachyon.TachyonProtobufIn do
  require Logger
  alias Teiserver.Tachyon.TachyonPbLib
  alias Teiserver.Tachyon.{ClientAuthHandler, AccountHandler}

  @spec handle(binary(), map) :: map
  def handle(raw_data, conn) do
    {{type, object}, metadata} = TachyonPbLib.client_decode_and_unwrap(raw_data)
    Logger.debug("WS in: " <> inspect_object(object))

    {result_type, result_object, conn_updates} = dispatch(type, object, conn)

    {result_type, result_object, metadata, conn_updates}
  end

  defp dispatch(type, object, state) do
    func = get_handler(type)
    {result_object, conn_updates} = case func.(object, state) do
      {result, updates} -> {result, updates}
      result -> {result, nil}
    end

    result_type = TachyonPbLib.get_atom(result_object.__struct__)

    {result_type, result_object, conn_updates}
  end

  @spec get_handler(atom) :: function
  defp get_handler(:myself_request), do: &AccountHandler.handle_myself_request/2

  defp get_handler(type), do: raise "No TachyonIn handler for type '#{type}'"

  # @spec dispatch(String.t(), map(), map()) :: map()
  # defp dispatch(nil, data, state) do
  #   reply(:system, :error, %{location: "dispatch", error: "cmd with nil value passed in with data '#{Kernel.inspect data}'"}, state)
  # end
  # defp dispatch(cmd, data, state) do
  #   state = state
  #     |> add_msg_id(data)

  #   new_state = case String.split(cmd, ".") do
  #     ["c", namespace, subcommand] ->
  #       case namespace do
  #         "auth" -> AuthIn.do_handle(subcommand, data, state)
  #         "client" -> ClientIn.do_handle(subcommand, data, state)
  #         "communication" -> CommunicationIn.do_handle(subcommand, data, state)
  #         "config" -> ConfigIn.do_handle(subcommand, data, state)
  #         "lobby_host" -> LobbyHostIn.do_handle(subcommand, data, state)
  #         "lobby" -> LobbyIn.do_handle(subcommand, data, state)
  #         "matchmaking" -> MatchmakingIn.do_handle(subcommand, data, state)
  #         "news" -> NewsIn.do_handle(subcommand, data, state)
  #         "party" -> PartyIn.do_handle(subcommand, data, state)
  #         "system" -> SystemIn.do_handle(subcommand, data, state)
  #         "telemetry" -> TelemetryIn.do_handle(subcommand, data, state)
  #         "user" -> UserIn.do_handle(subcommand, data, state)
  #         _ -> reply(:system, :error, %{location: "dispatch", error: "No dispatch for namespace '#{namespace}'"}, state)
  #       end
  #     _ ->
  #       reply(:system, :error, %{location: "parse", error: "Unable to parse cmd '#{cmd}'"}, state)
  #   end

  #   # And remove the msg_id, don't want that bleeding over
  #   %{new_state | msg_id: nil}
  # end

  defp inspect_object(object) do
    object
      |> Map.drop([:__unknown_fields__])
      |> inspect
  end
end
