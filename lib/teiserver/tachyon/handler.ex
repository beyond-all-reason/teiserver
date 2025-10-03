defmodule Teiserver.Tachyon.Handler do
  @moduledoc """
  Interface for connecting a tachyon client and process tachyon commands
  """

  alias Teiserver.Helpers.BurstyRateLimiter
  alias Teiserver.Tachyon.Schema

  @typedoc """
  A map to keep track of the response that are expected.
  The value is a pair of {timeout ref, opaque payload of data to handle the response}
  """
  @type pending_responses :: %{Schema.message_id() => {reference(), term()}}

  @type request_opt :: {:timeout, timeout()} | {:cb_state, term()}
  @type request_opts :: [request_opt()]

  @typedoc """
  Value to return to send an event to the peer.
  """
  @type tachyon_result ::
          {:event, Schema.command_id(), payload :: term(), state :: term()}
          | {:event, [{Schema.command_id(), payload :: term()}], state :: term()}
          | {:response, state :: term()}
          | {:response, payload :: term(), state :: term()}
          | {:response, {resp :: term(), events: [term()]}, state :: term()}
          | {:error_response, reason :: String.t() | atom(), state :: term()}
          | {:error_response, reason :: String.t() | atom(), details :: String.t(),
             state :: term()}
          | {:request, Schema.command_id(), payload :: term(), request_opts(), state :: term()}

  @type result :: tachyon_result() | WebSock.handle_result()

  @optional_callbacks handle_response: 4, init_rate_limiter: 1

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
  @callback init(term()) :: result()

  @doc """
  if required, should return a rate limiter. The state returned from `init` is the argument
  """
  @callback init_rate_limiter(term()) :: BurstyRateLimiter.t()

  @doc """
  Same as `WebSock.handle_info/2`
  """
  @callback handle_info(term(), term()) :: WebSock.handle_result()

  @doc """
  Called when receiving response before the timeout
  The second argument is the callback payload supplied in the :tachyon_reply tuple
  The third argument is the parsed response
  The fourth argument is the state
  """
  @callback handle_response(Schema.command_id(), term(), term(), term()) :: result()

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
            ) :: result()
end
