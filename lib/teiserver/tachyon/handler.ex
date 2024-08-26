defmodule Teiserver.Tachyon.Handler do
  @moduledoc """
  Interface for connecting a tachyon client and process tachyon commands
  """

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

  # TODO: add other callbacks to handle (parsed) tachyon commands
end
