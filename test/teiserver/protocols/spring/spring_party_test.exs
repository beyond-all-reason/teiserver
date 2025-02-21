defmodule Teiserver.Protocols.Spring.SpringPartyTest do
  use Teiserver.ServerCase, async: false
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Account.PartyLib

  alias Teiserver.Support.Polling

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_until: 1]

  defp setup_user(_context) do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  describe "create" do
    setup [:setup_user]

    test "create", %{socket: socket} do
      assert create_party!(socket) != nil
    end

    test "cannot create when in a party", %{socket: socket} do
      create_party!(socket)
      create_party(socket)
      assert {"NO", _, _} = _recv_until(socket) |> parse_in_message()
    end
  end

  defp create_party(socket) do
    msg_id = :rand.uniform(1_000_000) |> to_string()
    _send_raw(socket, "##{msg_id} c.party.create_new_party\n")
  end

  defp create_party!(socket) do
    create_party(socket)
    assert {"OK", %{"party_id" => party_id}, _} = _recv_until(socket) |> parse_in_message()

    Polling.poll_until_some(fn ->
      PartyLib.get_party(party_id)
    end)

    party_id
  end

  defp parse_in_message(raw) do
    case SpringIn.parse_in_message(raw) do
      nil ->
        nil

      {x, raw_args, y} ->
        args =
          String.split(raw_args, "\t")
          |> Enum.reduce(%{}, fn frag, m ->
            [k, v] = String.split(frag, "=")
            Map.put(m, String.trim(k), String.trim(v))
          end)

        {x, args, y}
    end
  end
end
