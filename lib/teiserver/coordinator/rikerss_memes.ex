defmodule Teiserver.Coordinator.RikerssMemes do
  @moduledoc false
  alias Teiserver.{Account, Battle}
  alias Teiserver.Lobby.{ChatLib}
  alias Teiserver.Data.Types, as: T

  @meme_list ~w(ticks nodefence nodefence2 greenfields poor rich hardt1 crazy undo deathmatch noscout hoversonly nofusion armonly coronly legonly randomizer)

  @crazy_multiplier_opts ~w(0.3 0.5 0.7 1 1 1 1 1 1 1 1.5 2 4)
  @crazy_multiplier_opts_middler ~w(0.5 0.7 1 1 1 1 1 1 1 1.5 2)
  @crazy_multiplier_opts_positive ~w(1 1 1 1 1.5 2)

  @spec handle_meme(String.t(), T.userid(), map()) :: [String.t()]
  def handle_meme("ticks", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    labs =
      ~w(armaap armalab armap armavp armhp armshltx armvp armamsub armasy armfhp armplat armshltxuw armsy)

    defences = ~w(armmg armllt armbeamer armhlt arm armdrag armclaw armguard armjuno)
    units = ~w(armham armjeth armpw armrectr armrock armwar)

    cortex =
      ~w(coraap coralab corap coravp corgant corhp corlab corvp corllt corfhp corsy corjuno corhllt corhlt)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/map_waterislava" => "1",
      "game/modoptions/faction_limiter" => "armada"
    })

    Battle.disable_units(lobby_id, labs ++ defences ++ units ++ cortex)

    [
      "#{sender.name} has enabled the Ticks meme. In this game the only fighting unit you will be able to build will be ticks."
    ]
  end

  def handle_meme("greenfields", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    Battle.disable_units(
      lobby_id,
      ~w(armmex armamex armmoho cormex corexp cormexp cormoho legmex legmext2 legmext15 coruwmex coruwmme armuwmex armuwmme armshockwave)
    )

    ["#{sender.name} has enabled the Greenfield meme. Metal extractors are disabled."]
  end

  def handle_meme("deathmatch", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/startmetal" => "35000",
      "game/modoptions/startenergy" => "1000",
      "game/modoptions/multiplier_maxvelocity" => "1.5",
      "game/modoptions/multiplier_buildpower" => "1.5",
      "game/modoptions/multiplier_weapondamage" => "1.5"
    })

    antinukes = ~w(armamd corfmd armscab cormabm armcarry corcarry)

    Battle.disable_units(lobby_id, antinukes)

    [
      "#{sender.name} has enabled the Deathmatch meme. You start with a 35k metal, 1k energy, everything builds fast, runs fast and hits hard. Beware, anti-nukes are disabled; Good luck Commander."
    ]
  end

  def handle_meme("poor", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    Battle.set_modoption(lobby_id, "game/modoptions/multiplier_resourceincome", "0")

    ["#{sender.name} has enabled the poor meme. Nobody can produce resources."]
  end

  def handle_meme("rich", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    Battle.set_modoptions(lobby_id, %{
      "game/modoptions/startmetal" => "100000000",
      "game/modoptions/startenergy" => "100000000",
      "game/modoptions/multiplier_resourceincome" => "1000"
    })

    ["#{sender.name} has enabled the rich meme. Everybody has insane amounts of resources."]
  end

  def handle_meme("hardt1", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    armada = ~w(armfhp armhp armamsub armplat armalab armavp armaap armasy armshltx armshltxuw)
    cortex = ~w(corfhp corhp coaramsub corplat coravp coralab coraap corgantuw corgant corasy)

    Battle.disable_units(lobby_id, armada ++ cortex)

    [
      "#{sender.name} has enabled the hard T1 meme. You can only build T1 (Seaplanes and Hovers are T1.5, they are disabled)."
    ]
  end

  def handle_meme("crazy", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    undo_memes(lobby_id)
    :timer.sleep(100)

    new_options = %{
      "game/modoptions/startmetal" => Enum.random(~w(500 750 1000 1500 2500 5000 10000 100000)),
      "game/modoptions/startenergy" =>
        Enum.random(~w(750 1000 1500 2500 5000 10000 100000 500000)),
      "game/modoptions/multiplier_resourceincome" =>
        Enum.random(~w(0.1 0.25 0.5 0.75 1 1.5 2 5 10)),
      "game/modoptions/maxunits" => Enum.random(~w(100 500 1000 2000 2000 2000 2000)),
      "game/modoptions/norushtimer" => Enum.random(~w(1 2 3 4 5 8 10 10)),
      "game/modoptions/norush" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/map_waterlevel" => Enum.random(~w(-200 -100 -50 0 0 0 0 50 100 200)),
      "game/modoptions/lootboxes" => Enum.random(~w(scav_only scav_only scav_only enabled)),
      "game/modoptions/lootboxes_density" => Enum.random(~w(veryrare rarer normal normal normal)),
      "game/modoptions/teamcolors_anonymous_mode" =>
        Enum.random(~w(disabled disabled disabled disco)),
      "game/modoptions/multiplier_shieldpower" => Enum.random(~w(1 1 1 2 3 4)),
      "game/modoptions/disable_fogofwar" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/assistdronesenabled" =>
        Enum.random(~w(disabled disabled disabled enabled)),
      "game/modoptions/assistdronescount" => Enum.random(~w(2 4 8 10 16)),
      "game/modoptions/experimentalextraunits" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/multiplier_maxdamage" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_turnrate" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_builddistance" => Enum.random(@crazy_multiplier_opts_positive),
      "game/modoptions/multiplier_weaponrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_metalcost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_energycost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_buildtimecost" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_weapondamage" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_buildpower" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_maxvelocity" => Enum.random(@crazy_multiplier_opts_middler),
      "game/modoptions/multiplier_losrange" => Enum.random(@crazy_multiplier_opts),
      "game/modoptions/multiplier_radarrange" => Enum.random(@crazy_multiplier_opts)
    }

    # Toggle default for some options based on others
    # Assist dronse
    new_options =
      if new_options["game/modoptions/assistdronesenabled"] != "enabled" do
        Map.put(new_options, "game/modoptions/assistdronescount", "10")
      else
        new_options
      end

    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the crazy meme. We've rolled some dice on a bunch of stuff and hopefully it'll make for a fun game."
    ]
  end

  def handle_meme("nodefence", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    armada_defences =
      ~w(armamb armamd armanni armbeamer armbrtha armclaw armemp armguard armhlt armjuno armmg armpb armsilo armvulc armatl armdl armfhlt armfrt armgplat armkraken armptl armtl)

    armada_aa = ~w(armferret armflak armmercury armrl armfflak armfrock armcir)

    cortex_defences =
      ~w(corbhmth corbuzz cordoom corexp corfmd corhllt corhlt corjuno cormaw cormexp corpun corsilo cortoast cortron corvipe coratl cordl corfdoom corfhlt corfrock corfrt corgplat corptl cortl corint)

    cortex_aa = ~w(corerad corflak cormadsam corrl corscreamer corenaa)

    scavt3 =
      ~w(armannit3 cordoomt3 armbotrail armminivulc corhllllt corminibuzz corscavdrag corscavdtf corscavdtl corscavdtm)

    legion_defences = ~w(legdefcarryt1 legmg)

    unit_list =
      armada_defences ++ armada_aa ++ cortex_defences ++ cortex_aa ++ scavt3 ++ legion_defences

    scav_units =
      unit_list
      |> Enum.map(fn unit -> "#{unit}_scav" end)

    Battle.disable_units(lobby_id, unit_list ++ scav_units)

    [
      "#{sender.name} has enabled the No defense meme. In this game you will not be able to create any defences; good luck!"
    ]
  end

  def handle_meme("nodefence2", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    armada_defences =
      ~w(armllt armamb armamd armanni armbeamer armbrtha armclaw armemp armguard armhlt armjuno armmg armpb armsilo armvulc armatl armdl armfhlt armfrt armgplat armkraken armptl armtl)

    armada_aa = ~w(armferret armflak armmercury armrl armfflak armfrock armcir)

    cortex_defences =
      ~w(corllt corbhmth corbuzz cordoom corexp corfmd corhllt corhlt corjuno cormaw cormexp corpun corsilo cortoast cortron corvipe coratl cordl corfdoom corfhlt corfrock corfrt corgplat corptl cortl corint)

    cortex_aa = ~w(corerad corflak cormadsam corrl corscreamer corenaa)

    scavt3 =
      ~w(armannit3 cordoomt3 armbotrail armminivulc corhllllt corminibuzz corscavdrag corscavdtf corscavdtl corscavdtm)

    legion_defences = ~w(legdefcarryt1 legmg)

    unit_list =
      armada_defences ++ armada_aa ++ cortex_defences ++ cortex_aa ++ scavt3 ++ legion_defences

    scav_units =
      unit_list
      |> Enum.map(fn unit -> "#{unit}_scav" end)

    Battle.disable_units(lobby_id, unit_list ++ scav_units)

    [
      "#{sender.name} has enabled the No defense meme, No LLTs ver. In this game you will not be able to create any defences; good luck!"
    ]
  end

  def handle_meme("noscout", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    arm_scouts =
      ~w(armflea armfav armmark armseer armpeep armawac armrad armspy armarad armeyes armfrad armason armsehak)

    cor_scouts =
      ~w(corfav corvoyr corvrad corfink corawac corrad corarad corspy coreyes corfrad corason corhunt)

    Battle.disable_units(lobby_id, arm_scouts ++ cor_scouts)

    [
      "#{sender.name} has enabled the No Scouts meme. In this game you will not be able to create any scout, radar, or spy units; good luck!"
    ]
  end

  def handle_meme("hoversonly", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    new_options = %{
      "game/modoptions/tweakdefs" =>
        "bG9jYWwgZnVuY3Rpb24gZEMoU1QsIGNvcCkKCWNvcD1jb3Agb3Ige30KCWxvY2FsIE5UPXt9Cgljb3BbU1RdPU5UCglmb3IgaywgdiBpbiBwYWlycyhTVCkgZG8KCQlpZiB0eXBlKHYpPT0idGFibGUiIHRoZW4KCQkJaWYgTlRba109PW5pbCB0aGVuIE5UW2tdPXt9IGVuZAoJCQlOVFtrXT1jb3Bbdl0gb3IgZEModiwgY29wKQoJCWVsc2UgTlRba109diBlbmQKCWVuZAoJcmV0dXJuIE5UCmVuZApsb2NhbCB1ZCA9IFVuaXREZWZzCmZvciBjb20saW5mIGluIHBhaXJzKHthcm1jb209eyJhcm0iLCJhcm1jaCJ9LGNvcmNvbT17ImNvciIsImNvcmNoIn0sfSkgZG8KCWxvY2FsIHRlbXAgPSBkQyh1ZFtjb21dLmJ1aWxkb3B0aW9ucykKCWxvY2FsIHRlbXAyID0gZEModWRbY29tXS5jdXN0b21wYXJhbXMpCgl1ZFtjb21dPWRDKHVkW2luZlsyXV0pCgl1ZFtjb21dLmJ1aWxkb3B0aW9ucyA9IHRlbXAKCXVkW2NvbV0uY3VzdG9tcGFyYW1zID0gdGVtcDIKCXVkW2NvbV0uaWNvbnR5cGU9aW5mWzFdLi4iY29tbWFuZGVyIgoJdWRbY29tXS5zb3VuZHMudW5kZXJhdHRhY2s9Indhcm5pbmcyIgoJdWRbY29tXS5zb3VuZHMuc2VsZWN0PXtbMV09aW5mWzFdLi4iY29tc2VsIn0KCWZvciBwYXJtLCB2YWwgaW4gcGFpcnMoe3JlY2xhaW1hYmxlPWZhbHNlLHdvcmtlcnRpbWU9MzAwLG1ldGFsbWFrZT0yLG1ldGFsc3RvcmFnZT01MDAsZW5lcmd5bWFrZT0yNSxlbmVyZ3lzdG9yYWdlPTUwMCxtYXhkYW1hZ2U9MzcwMCxhdXRvaGVhbD01LHNob3dwbGF5ZXJuYW1lID0gdHJ1ZSxjYW5tYW51YWxmaXJlID0gdHJ1ZSx9KSBkbwoJCXVkW2NvbV1bcGFybV0gPSB2YWwKCWVuZAplbmQKdWQubGVnY29tID0gZEModWQuY29yY29tKQ"
    }

    cor_not_hover_fac =
      ~w(corsy corlab corvp corap coramsub corplat coravp coralab corasy coraap corgantuw corgant)

    arm_not_hover_fac =
      ~w(armsy armlab armvp armap armamsub armplat armalab armavp armaap armasy armshltx armshltxuw)

    leg_not_hover_fac = ~w(leglab legvp legap legalab legavp legaap leggant)
    Battle.set_modoptions(lobby_id, new_options)
    Battle.disable_units(lobby_id, cor_not_hover_fac ++ arm_not_hover_fac ++ leg_not_hover_fac)

    [
      "#{sender.name} has enabled the Hovers Only meme. In this game you will be limited to hovers only, including your commander; good luck!"
    ]
  end

  def handle_meme("nofusion", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    fusion_units = ~w(armfus armafus armuwfus armckfus corfus corafus coruwfus)
    Battle.disable_units(lobby_id, fusion_units)

    [
      "#{sender.name} has enabled the No Fusion meme. In this game you will not be able to create any T2 Fusion Energy production; good luck!"
    ]
  end

  def handle_meme("armonly", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    new_options = %{"game/modoptions/faction_limiter" => "armada"}
    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the Armada Only meme. A fight of Technological Supremacy upon you; good luck!"
    ]
  end

  def handle_meme("coronly", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    new_options = %{"game/modoptions/faction_limiter" => "cortex"}
    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the Cortex Only meme. May pure Brute Strength grant you Honour in battle; good luck!"
    ]
  end

  def handle_meme("legonly", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    new_options = %{
      "game/modoptions/faction_limiter" => "legion",
      "game/modoptions/experimentallegionfaction" => "1"
    }

    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the Legion Only meme. Scorched Earth be upon us all; good luck!"
    ]
  end

  def handle_meme("randomizer", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)

    new_options = %{
      "game/modoptions/tweakdefs" =>
        "bG9jYWwgcG9vbHMgPSB7ClsxXT17ImFybWFwIiwiYXJtdnAiLCJhcm1ocCIsImFybWxhYiIsImNvcmFwIiwiY29ydnAiLCJjb3JocCIsImNvcmxhYiJ9LFsyXT17ImFybWFhcCIsImFybWF2cCIsImFybWFsYWIiLCJjb3JhYXAiLCJjb3JhdnAiLCJjb3JhbGFiIn0sClszXT17ImFybWZocCIsImFybXBsYXQiLCJhcm1zeSIsImNvcmZocCIsImNvcnBsYXQiLCJjb3JzeSJ9LFs0XT17ImFybXNobHR4IiwiY29yZ2FudCJ9LFs1XT17ImFybXNobHR4dXciLCJjb3JnYW50dXcifSxbNl09eyJjb3Jjb20iLCJhcm1jb20ifSwKWzddPXsiY29yY2EiLCJjb3JjdiIsImNvcmNrIiwiYXJtY2EiLCJhcm1jdiIsImFybWNrIn0sWzhdPXsiY29yY2giLCJhcm1jaCIsImFybWNzYSIsImNvcmNzYSIsImNvcm11c2tyYXQiLCJhcm1iZWF2ZXIiLCJjb3JjcyIsImFybWNzIn0sCls5XT17ImNvcmFjYSIsImNvcmFjayIsImNvcmFjdiIsImFybWFjYSIsImFybWFjayIsImFybWFjdiJ9LFsxMF09eyJjb3JhY3N1YiIsImFybWFjc3ViIn0sWzExXT17ImNvcm1sdiIsImFybW1sdiJ9LApbMTJdPXsiY29ybWFuZG8iLCJjb3JmYXN0IiwiYXJtZmFyayIsImFybWRlY29tIiwiY29yZGVjb20ifSxbMTNdPXsiY29yYXN5IiwiYXJtYXN5In0sfQpsb2NhbCBmdW5jdGlvbiBjb250YWlucyhuYW1lLCBsaXN0KQoJZm9yIGksIG5tIGluIHBhaXJzKGxpc3QpIGRvCgkJaWYgbm0gPT0gbmFtZSB0aGVuCgkJCXJldHVybiB0cnVlCgkJZW5kCgllbmQKCXJldHVybiBmYWxzZQplbmQKbG9jYWwgdWQgPSBVbml0RGVmcwpmb3IgXywgc3dwIGluIHBhaXJzKHsKWzFdPXsiYXJtYXAiLCJhcm1ocCJ9LFsyXT17ImFybWFhcCIsImFybWhwIn0sWzNdPXsiYXJtcGxhdCIsImFybWZocCJ9LFs0XT17ImNvcmFwIiwiY29yaHAifSwKWzVdPXsiY29yYWFwIiwiY29yaHAifSxbNl09eyJjb3JwbGF0IiwiY29yZmhwIn0sWzddPXsibGVnYXAiLCJjb3JmaHAifSxbOF09eyJsZWdhYXAiLCJjb3JmaHAifSwKfSkgZG8gZm9yIGEsIF8gaW4gcGFpcnMoe29iamVjdG5hbWU9MSxzY3JpcHQ9Mix5YXJkbWFwPTMsY29sbGlzaW9udm9sdW1lb2Zmc2V0cz00LGNvbGxpc2lvbnZvbHVtZXNjYWxlcz01LGNvbGxpc2lvbnZvbHVtZXR5cGU9Nixmb290cHJpbnR4PTcsZm9vdHByaW50ej04fSkgZG8KdWRbc3dwWzFdXVthXT11ZFtzd3BbMl1dW2FdIAplbmQgZW5kCmxvY2FsIGZ1bmN0aW9uIGFkZChhZGRUaGlzLCB0b1RoaXMpCmZvciBpID0gMSwgI2FkZFRoaXMgZG8KcG9vbHNbdG9UaGlzXVsjcG9vbHNbdG9UaGlzXSsxXSA9IGFkZFRoaXNbaV0KZW5kIGVuZAppZiBTcHJpbmcuR2V0TW9kT3B0aW9ucygpLmV4cGVyaW1lbnRhbGxlZ2lvbmZhY3Rpb24gPT0gdHJ1ZSB0aGVuCmFkZCh7ImxlZ2FwIiwibGVndnAiLCJsZWdsYWIifSwxKQphZGQoeyJsZWdhYXAiLCJsZWdhdnAiLCJsZWdhbGFiIn0sMikKcG9vbHNbNF1bI3Bvb2xzWzRdKzFdPSJsZWdnYW50IgphZGQoeyJsZWdjb20iLCJsZWdjb21sdmwyIiwibGVnY29tbHZsMyIsImxlZ2NvbWx2bDQifSw2KQphZGQoeyJsZWdjYSIsImxlZ2NrIiwibGVnY3YifSw3KQphZGQoeyJsZWdhY2EiLCJsZWdhY2siLCJsZWdhY3YifSw5KQplbmQKbG9jYWwgZmlsdHMgPSB7fQpmb3IgbmFtZSwgdW5pdCBpbiBwYWlycyh1ZCkgZG8KCWlmIHVuaXQuY3VzdG9tcGFyYW1zIGFuZCB1bml0LmN1c3RvbXBhcmFtcy5tZXRhbF9leHRyYWN0b3IgdGhlbgoJCWlmIHVuaXQubWlud2F0ZXJkZXB0aCB0aGVuCgkJCWZpbHRzW25hbWVdID0gIm11IgoJCWVsc2UKCQkJZmlsdHNbbmFtZV0gPSAibSIKCQllbmQKCWVsc2VpZiB1bml0LmJ1aWxkb3B0aW9ucyBhbmQgdW5pdC5jdXN0b21wYXJhbXMgYW5kIHVuaXQuY3VzdG9tcGFyYW1zLnVuaXRncm91cCBhbmQgc3RyaW5nLmZpbmQodW5pdC5jdXN0b21wYXJhbXMudW5pdGdyb3VwLCdidWlsZGVyJykgdGhlbgoJCWlmIHVuaXQuaWNvbnR5cGUgYW5kIHVuaXQuaWNvbnR5cGUgPT0gImJ1aWxkaW5nIiB0aGVuCgkJCWlmIHVuaXQuY3VzdG9tcGFyYW1zLnRlY2hsZXZlbCBhbmQgdW5pdC5jdXN0b21wYXJhbXMudGVjaGxldmVsID09IDMgdGhlbgoJCQkJaWYgdW5pdC5taW53YXRlcmRlcHRoIHRoZW4KCQkJCQlmaWx0c1tuYW1lXSA9ICJmdTMiCgkJCQllbHNlCgkJCQkJZmlsdHNbbmFtZV0gPSAiZjMiCgkJCQllbmQKCQkJZWxzZWlmIHVuaXQuY3VzdG9tcGFyYW1zLnRlY2hsZXZlbCBhbmQgdW5pdC5jdXN0b21wYXJhbXMudGVjaGxldmVsID09IDIgdGhlbgoJCQkJaWYgdW5pdC5taW53YXRlcmRlcHRoIHRoZW4KCQkJCQlmaWx0c1tuYW1lXSA9ICJmdTIiCgkJCQllbHNlCgkJCQkJZmlsdHNbbmFtZV0gPSAiZjIiCgkJCQllbmQKCQkJZWxzZQoJCQkJaWYgdW5pdC5taW53YXRlcmRlcHRoIHRoZW4KCQkJCQlmaWx0c1tuYW1lXSA9ICJmdSIKCQkJCWVsc2UKCQkJCQlmaWx0c1tuYW1lXSA9ICJmIgoJCQkJZW5kCgkJCWVuZAoJCWVsc2UKCQkJbG9jYWwgZXhjID0ge2Nvcm1hbmRvPTEsYXJtZmFyaz0xLGNvcmZhc3Q9MSxjb3JtbHY9MSxhcm1tbHY9MSxjb3JkZWNvbT0xLGFybWRlY29tPTEsY29ybWxzPTEsYXJtbWxzPTF9CgkJCWlmIGV4Y1tuYW1lXSA9PSBuaWwgdGhlbgoJCQkJZmlsdHNbbmFtZV0gPSAiYyIKCQkJZW5kCgkJZW5kCgllbHNlaWYgdW5pdC5lbmVyZ3ltYWtlIHRoZW4KCQlpZiB1bml0LmN1c3RvbXBhcmFtcy5nZW90aGVybWFsID09IG5pbCB0aGVuCgkJCWlmIHVuaXQubWlud2F0ZXJkZXB0aCB0aGVuCgkJCQlmaWx0c1tuYW1lXSA9ICJldSIKCQkJZWxzZQoJCQkJZmlsdHNbbmFtZV0gPSAiZSIKCQkJZW5kCgkJZW5kCgllbmQKZW5kCmxvY2FsIHJlcXM9e1sxXT17ImMifSxbMl09eyJjIn0sWzNdPXsiYyJ9LApbNF09e30sWzVdPXt9LFs2XT17Im0iLCJtdSIsImUiLCJldSIsImYiLCJmdSJ9LApbN109eyJtIiwiZSIsImYiLCJmMiJ9LFs4XT17Im11IiwiZXUiLCJmdSIsImZ1MiJ9LApbOV09eyJtIiwiZSIsImYyIiwiZjMifSxbMTBdPXsibXUiLCJldSIsImZ1MiIsImZ1MyJ9LApbMTFdPXt9LFsxMl09eyJtIiwiZSIsImYifSxbMTNdPXsiYyJ9LH0KbG9jYWwgZnVuY3Rpb24gZmluZEZpbHQoaSwgbCkKCWZvciBqID0gMSwgI3JlcXNbaV0gZG8KCQlpZiByZXFzW2ldW2pdID09IGwgdGhlbgoJCQlyZXR1cm4gdHJ1ZQoJCWVuZAoJZW5kCglyZXR1cm4gZmFsc2UKZW5kCmZvciBpID0gMSwgI3Bvb2xzIGRvCmxvY2FsIHBvb2wgPSBwb29sc1tpXQpsb2NhbCBtaW5zPXttPXt9LG11PXt9LGU9e30sZXU9e30sYz17fSxmPXt9LGZ1PXt9LGYyPXt9LGZ1Mj17fSxmMz17fSxmdTM9e319CmxvY2FsIFRVUCA9IHt9CmZvciBfLCBuYW1lIGluIHBhaXJzKHBvb2wpIGRvCglsb2NhbCBibyA9IHVkW25hbWVdLmJ1aWxkb3B0aW9ucwoJbG9jYWwgZgoJZm9yIGkgPSAxLCAjYm8gZG8KCQlmID0gZmlsdHNbYm9baV1dCgkJaWYgZiB0aGVuIG1pbnNbZl1bI21pbnNbZl0rMV09Ym9baV0KCQllbHNlIFRVUFsjVFVQKzFdID0gYm9baV0KCQllbmQKCQlib1tpXSA9IG5pbAoJZW5kCmVuZApmb3IgbCwgbWluIGluIHBhaXJzKG1pbnMpIGRvCglpZiBmaW5kRmlsdChpLCBsKSB0aGVuCgkJbG9jYWwgcm5nLCB0bXAsIGJvCgkJZm9yIGkgPSAxLCAjbWluIGRvCgkJCXJuZyA9IG1hdGgucmFuZG9tKDEsICNtaW4pCgkJCXRtcCA9IG1pbltpXQoJCQltaW5baV0gPSBtaW5bcm5nXQoJCQltaW5bcm5nXSA9IHRtcAoJCWVuZAoJCWxvY2FsIGNhcCA9IG1hdGgubWluKCNtaW4sI3Bvb2wpCgkJZm9yIGkgPSAxLCBjYXAgZG8KCQkJYm8gPSB1ZFtwb29sW2ldXS5idWlsZG9wdGlvbnMKCQkJYm9bI2JvKzFdID0gbWluW2ldCgkJZW5kCgkJZm9yIGkgPSBjYXAgKyAxLCAjbWluIGRvCgkJCVRVUFsjVFVQKzFdID0gbWluW2ldCgkJZW5kCgllbHNlCgkJZm9yIGkgPSAxLCAjbWluIGRvCgkJCVRVUFsjVFVQKzFdID0gbWluW2ldCgkJZW5kCgllbmQKZW5kCmZvciBpLCBuYW1lIGluIHBhaXJzKFRVUCkgZG8KCWxvY2FsIGZhYyA9IHBvb2xbbWF0aC5yYW5kb20oMSwgI3Bvb2wpXQoJbG9jYWwgYm8gPSB1ZFtmYWNdLmJ1aWxkb3B0aW9ucwoJd2hpbGUgY29udGFpbnMobmFtZSwgYm8pIGRvCgkJZmFjID0gcG9vbFttYXRoLnJhbmRvbSgxLCAjcG9vbCldCgkJYm8gPSB1ZFtmYWNdLmJ1aWxkb3B0aW9ucwoJZW5kCglib1sjYm8rMV0gPSBUVVBbaV0KZW5kCmVuZA",
      "game/modoptions/experimentalextraunits" => "0"
    }

    Battle.set_modoptions(lobby_id, new_options)

    [
      "#{sender.name} has enabled the sanitized Randomizer meme. Get ready to roll dices, mexes, e-gen, con and labs guaranteed!"
    ]
  end

  def handle_meme("undo", _senderid, %{lobby_id: lobby_id} = _state) do
    undo_memes(lobby_id)

    [
      "Meme modes have been (as best as possible) undone. Please check the game settings still in place to ensure they have all been removed."
    ]
  end

  def handle_meme(_meme, senderid, state) do
    ChatLib.sayprivateex(
      state.coordinator_id,
      senderid,
      "That's not a valid meme. The memes are #{Enum.join(@meme_list, ", ")}",
      state.lobby_id
    )

    []
  end

  def undo_memes(lobby_id) do
    Battle.enable_all_units(lobby_id)

    new_options = %{
      "game/modoptions/startmetal" => "1000",
      "game/modoptions/startenergy" => "1000",
      "game/modoptions/multiplier_resourceincome" => "1",
      "game/modoptions/maxunits" => "2000",
      "game/modoptions/norushtimer" => "5",
      "game/modoptions/norush" => "0",
      "game/modoptions/map_waterlevel" => "0",
      "game/modoptions/lootboxes" => "scav_only",
      "game/modoptions/lootboxes_density" => "normal",
      "game/modoptions/teamcolors_anonymous_mode" => "disabled",
      "game/modoptions/multiplier_shieldpower" => "1",
      "game/modoptions/disable_fogofwar" => "0",
      "game/modoptions/assistdronesenabled" => "disabled",
      "game/modoptions/assistdronescount" => "10",
      "game/modoptions/experimentalextraunits" => "0",
      "game/modoptions/multiplier_maxdamage" => "1",
      "game/modoptions/multiplier_turnrate" => "1",
      "game/modoptions/multiplier_builddistance" => "1",
      "game/modoptions/multiplier_weaponrange" => "1",
      "game/modoptions/multiplier_metalcost" => "1",
      "game/modoptions/multiplier_energycost" => "1",
      "game/modoptions/multiplier_buildtimecost" => "1",
      "game/modoptions/multiplier_weapondamage" => "1",
      "game/modoptions/multiplier_buildpower" => "1",
      "game/modoptions/multiplier_maxvelocity" => "1",
      "game/modoptions/multiplier_losrange" => "1",
      "game/modoptions/multiplier_radarrange" => "1",
      "game/modoptions/tweakdefs" => "ZG8gZW5k",
      "game/modoptions/experimentallegionfaction" => "0",
      "game/modoptions/faction_limiter" => "0"
    }

    Battle.set_modoptions(lobby_id, new_options)
  end
end
