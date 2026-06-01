defmodule Teiserver.TachyonLobby.Types.Types do
  @moduledoc """
  central location for lobby related types that aren't really suited to be structs
  """

  @typedoc """
  These represent the indices respectively into
  {ally team index, team index, player index}
  since we don't really support "archon mode" though, the player index
  is likely always going to be 0.
  For example, a player in the first ally team, in the second spot
  would have: {0, 1, 0}
  """
  @type team ::
          {allyTeam :: non_neg_integer(), team :: non_neg_integer(), player :: non_neg_integer()}

  @type asset_status :: :missing | :downloading | :complete
end
