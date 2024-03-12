## Tachyon protocol
Tachyon is a protocol specification as defined in [the Tachyon repo](https://github.com/beyond-all-reason/tachyon). If you want to see the specs for the protocol you will need to go there. This document is for documenting/describing the Barserver implementation and internals of the protocol.

## Request handlers
For handling protocol requests

```elixir
defmodule Barserver.Tachyon.Handlers.{Section}.{Action}Request do
  @moduledoc false
  
  alias Barserver.Data.Types, as: T
  alias Barserver.Tachyon.Responses.{Section}.{Action}Response

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

If you implement the correct module naming convention and `dispatch_handlers` function it will be automatically loaded by `Barserver.Tachyon.CommandDispatch` on startup. If you need to reload the dispatches you can use `Barserver.Tachyon.CommandDispatch.build_dispatch_cache()`.

## Response generators
For creating protocol responses

## Message handlers
These are for handling internal PubSub messages


