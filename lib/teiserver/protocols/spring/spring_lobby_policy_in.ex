defmodule Teiserver.Protocols.Spring.LobbyPolicyIn do
  alias Teiserver.Battle.Lobby
  alias Teiserver.{Coordinator, Game}
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle(_, _, _, %{userid: nil} = state), do: state

  def do_handle("list", new_name, msg_id, state) do
    policies =
      Game.list_cached_lobby_policies()
      |> Enum.map(fn lp ->
        Map.take(lp, ~w(name preset icon colour enabled agent_name_list)a)
      end)

    reply(:lobby_policy, :list, policies, nil, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.lobby_policy." <> cmd, msg_id, data)
  end
end
