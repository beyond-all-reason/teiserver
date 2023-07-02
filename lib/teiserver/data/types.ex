defmodule Teiserver.Data.Types do
  # alias Teiserver.Data.Types, as: T

  @type userid() :: non_neg_integer()
  @type party_id() :: String.t()
  @type lobby_id() :: non_neg_integer()
  @type lobby_struct() :: Teiserver.Lobby.LobbyStruct.t()

  @type clan_id() :: non_neg_integer
  @type match_id() :: non_neg_integer
  @type queue_id() :: non_neg_integer

  @type mm_match_id() :: String.t()

  @type lobby() :: map()
  @type client() :: map()
  @type user() :: map()

  @type spring_tcp_state() :: map()
  @type tachyon_tcp_state() :: map()
  @type tachyon_ws_state() :: map()

  @type tachyon_conn() :: map()
  @type tachyon_command() :: String.t()
  @type tachyon_object() :: map()
  @type tachyon_response() :: {tachyon_command(), :success, tachyon_object()} | {T.tachyon_command, T.error_pair}
  @type error_pair() :: {:error, String.t()}

  @type lobby_server_state() :: map()
  @type consul_state() :: map()
  @type balance_server_state() :: map()

  @type lobby_policy_id() :: non_neg_integer()

  @type party() :: Teiserver.Account.Party.t()
end
