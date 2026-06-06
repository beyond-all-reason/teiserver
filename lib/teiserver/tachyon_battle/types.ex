defmodule Teiserver.TachyonBattle.Types do
  @moduledoc """
  for shared types across the tachyon battle modules when there is no clear
  module that should own them
  """
  alias Teiserver.Account.User

  @type id :: String.t()
  @type match_id :: non_neg_integer()
  @type add_player_data :: %{
          battle_id: id(),
          user_id: User.id(),
          name: String.t(),
          password: String.t()
        }
end
