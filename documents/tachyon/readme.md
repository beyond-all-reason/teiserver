## Tachyon protocol
Tachyon is a protocol specification as defined in [the Tachyon repo](https://github.com/beyond-all-reason/tachyon). If you want to see the specs for the protocol you will need to go there. This document is for documenting/describing the Teiserver implementation and internals of the protocol.

## Request handlers
For handling protocol requests

```elixir
defmodule Teiserver.Tachyon.Handlers.{Section}.{Action}Request do
  @moduledoc false
  
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.{Section}.{Action}Response

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "{section}/{action}/request" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, _object, _meta) do
    # Do stuff here
    
    # Create the response
    response = {Action}Response.generate(:ok)

    # Send the response and updated conn object
    {response, %{conn | lobby_host: false, lobby_id: nil}}
  end
end
```

## Response generators
For creating protocol responses

## Message handlers
These are for handling internal PubSub messages


