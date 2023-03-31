defmodule Teiserver.Protocols.Spring.LobbyPolicyOut do
  # alias Teiserver.Account
  # alias Teiserver.Battle.Lobby

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  def do_reply(_, _, %{userid: nil}), do: ""

  def do_reply(:list, policy_list, _state) do
    policy_rows =
      policy_list
      |> Enum.map(fn lp ->
        json = Jason.encode!(lp)
        "s.lobby_policy.list entry\t#{json}\n"
      end)

    ["s.lobby_policy.list start\n"] ++ policy_rows ++ ["s.lobby_policy.list end\n"]
  end
end
