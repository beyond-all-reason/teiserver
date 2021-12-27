defmodule Teiserver.Data.Types do
  # alias Teiserver.Data.Types, as: T
  @type userid() :: integer()
  @type lobby_id() :: integer()
  @type lobby_guid() :: String.t()
  @type clan_id() :: integer()

  @type lobby() :: map()
  @type client() :: map()
  @type user() :: map()
end
