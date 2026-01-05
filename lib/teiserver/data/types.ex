defmodule Teiserver.Data.Types do
  @doc """
  A list of types in one place to make it easier to reference them

  alias Teiserver.Data.Types, as: T
  """

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
  # credo:disable-for-next-line Credo.Check.Design.TagTODO
  # TODO: We should drop the next line and replace all calls with `Teiserver.Account.User.t()`.
  @type user() :: map()

  @type spring_tcp_state() :: map()
  @type error_pair() :: {:error, String.t()}

  @type lobby_server_state() :: map()
  @type consul_state() :: map()
  @type balance_server_state() :: map()

  @type lobby_policy_id() :: non_neg_integer()

  @type party() :: Teiserver.Account.Party.t()

  # This function exists purely to prevent an error appearing for the module docstring
  def z_do_nothing, do: :ok
end
