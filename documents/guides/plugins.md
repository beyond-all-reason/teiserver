# Plugins

Teiserver is written for the game Beyond All Reason but we appreciate there may be desire to use it for other games and as such we have a plugin system for those who want to extend it.

## Plugin structure

Plugins have three components:
- A hook point in the Teiserver code with `@decorate Plugins.plugin(:function_key)`
- Implementation by a 3rd party
- A function key listed in the configuration pointing to said implementation

## Writing a plugin

Writing a plugin is as simple as looking at the documentation around the plugin hook, implementing the appropriate function for it and then including that in your deployment of Teiserver.

### Example plugin

We will make a plugin for the `send_chat_message` hook. We will add a prefix to chat messages saying if the sender has an odd or even number of characters in their name.

```elixir
defmodule Teiserver.ExternalPlugins.ChatPlugins do
  @moduledoc false

  alias Teiserver.Chat.RoomServer

  @doc """
  Prefixes every message with an (odd) or (even) depending on if the
  user in question has an odd or even number of characters in their name.
  """
  def send_message(room_name, user, msg) do
    even? = user.name
      |> String.length()
      |> rem(2) == 0

    msg = if even? do
      "(even) " <> msg
    else
      "(odd) " <> msg
    end

    RoomServer.send_message(room_name, user.id, msg)
  end
end
```

After this we just need to update our config (*not* the runtime config, this uses macros so must be compile time) to point towards this function:

```elixir
config :teiserver, Teiserver.Plugins,
  send_chat_message: &Teiserver.ExternalPlugins.ChatPlugins.send_message/1,
```

And we are all set! Do note that at this stage of development implementing plugins will break Teiserver unit tests so they will need to be updated to correctly test whatever behaviour is being added.

## Plugin hook list

Every plugin is decorated with `@decorate Plugins.plugin`. At the present we are not sure how we wish to document the plugins so will only list the presence of them.

- `:send_chat_message` in `Teiserver.Room.send_message/3`
- `:send_chat_message_ex` in `Teiserver.Room.send_message_ex/3`

## Development of new plugin hooks

To add a new plugin hook you will need to:
- Add `alias Teiserver.Plugins` and `use Plugins` to the top of the module
- Add `@decorate Plugins.plugin(:function_key)` before the function, replace `:function_key` with a relevant atom key
- Extend the list/documentation around above to incorporate it
