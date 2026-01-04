defmodule Teiserver.TachyonBattle.Types do
  @moduledoc """
  for shared types across the tachyon battle modules when there is no clear
  module that should own them
  """

  @type id :: String.t()
  @type match_id :: non_neg_integer()
end
