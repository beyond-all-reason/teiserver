defmodule Teiserver.Protocols.Spring.LobbyPolicyIn do
  alias Teiserver.{Game}
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle(_, _, _, %{userid: nil} = state), do: state

  def do_handle("list", _, msg_id, state) do
    policies =
      Game.list_cached_lobby_policies()
      |> Enum.map(fn lp ->
        Map.take(lp, ~w(name preset icon colour enabled agent_name_list)a)
      end)

    reply(:lobby_policy, :list, policies, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.lobby_policy." <> cmd, msg_id, data)
  end
end
