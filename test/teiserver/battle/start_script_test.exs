defmodule Teiserver.Battle.StartScriptTest do
  use Teiserver.DataCase, async: false

  alias Teiserver.Battle

  test "test start script duel" do
    user1 = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    user2 = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

    start_script = %{
      game_name: "Beyond All Reason test-28379-33ba377",
      ally_teams: [
        %{
          teams: [
            %{
              players: [
                %{
                  name: user1.name,
                  user_id: user1.id,
                  password: "AAAAAAA"
                }
              ]
            }
          ],
          startBox: %{left: 0, right: 0.25, top: 0, bottom: 1}
        },
        %{
          teams: [
            %{
              players: [
                %{
                  name: user2.name,
                  user_id: user2.id,
                  password: "BBBBBBB"
                }
              ]
            }
          ],
          startBox: %{left: 0.75, right: 1, top: 0, bottom: 1}
        }
      ],
      map_name: "BarR 1.1",
      engine_version: "2025.04.04",
      spectators: [],
      start_pos_type: :ingame
    }

    {:ok, match} = Battle.create_match_from_start_script(start_script, false)
    assert Battle.get_match_membership(user1.id, match.id) != nil
    assert Battle.get_match_membership(user2.id, match.id) != nil
  end

  test "test start script 1 vs bot" do
    user1 = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

    start_script = %{
      game_name: "Beyond All Reason test-28379-33ba377",
      ally_teams: [
        %{
          teams: [
            %{
              players: [
                %{
                  name: user1.name,
                  user_id: user1.id,
                  password: "AAAAAAA"
                }
              ]
            }
          ],
          startBox: %{left: 0, right: 0.25, top: 0, bottom: 1}
        },
        %{
          teams: [
            %{bots: [%{name: "BARbarIAn", host_user_id: user1.id, ai_short_name: "BARb"}]}
          ],
          startBox: %{left: 0.75, right: 1, top: 0, bottom: 1}
        }
      ],
      map_name: "BarR 1.1",
      engine_version: "2025.04.04",
      spectators: [],
      start_pos_type: :ingame
    }

    {:ok, match} = Battle.create_match_from_start_script(start_script, false)
    assert Battle.get_match_membership(user1.id, match.id) != nil
  end
end
