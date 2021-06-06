# defmodule Teiserver.Protocols.Director.JoiningTest do
#   use Central.ServerCase, async: false
#   alias Teiserver.TeiserverTestLib
#   alias Teiserver.Battle
#   alias Teiserver.Common.PubsubListener
#   alias Teiserver.Director

#   @sleep 200

#   setup do
#     Teiserver.Director.start_director()
#     :timer.sleep(100)

#     battle = TeiserverTestLib.make_battle()
#     Battle.say(1, "!director start", battle.id)
#     :timer.sleep(@sleep)

#     {:ok, battle_id: battle.id}
#   end

#   test "join limiters", %{battle_id: battle_id} do
#     msg = "!set welcome-message This is the welcome message"
#     assert Director.handle_in(userid, msg, battle_id) == :ok
#   end
# end
