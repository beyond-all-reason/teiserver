defmodule Teiserver.Tachyon.Handler do
  @moduledoc """
  Interface for connecting a tachyon client and process tachyon commands
  """

  alias Teiserver.Tachyon.Schema

  @doc """
  Called when upgrading the http connection to websocket.
  It is given the connection object and should do whatever is required for
  logging in. It should also return the initial state for the websocket connection.
  """
  # ok to connect + state
  @callback connect(Plug.Conn.t()) ::
              {:ok, term()}
              # general error -> will return a 500
              | :error
              # error, http code and message
              | {:error, non_neg_integer(), String.t()}

  @doc """
  Same as `WebSock.init/1`
  """
  @callback init(term()) :: WebSock.handle_result()

  @doc """
  Same as `WebSock.handle_info/2`
  """
  @callback handle_info(term(), term()) :: WebSock.handle_result()

  @doc """
  The generic command handler. At that point, the message has already been
  validated against the corresponding json schema
  """
  @callback handle_command(
              Schema.command_id(),
              Schema.message_type(),
              Schema.message_id(),
              # message
              term(),
              # handler's state
              term()
            ) :: WebSock.handle_result()
end
