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

    Battle.disable_units(lobby_id, ~w(armmex armamex armmoho cormex corexp cormexp cormoho legmex legmext2 legmext15 coruwmex coruwmme armuwmex armuwmme armshockwave))

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
      "game/modoptions/lootboxes_density" =>
        Enum.random(~w(veryrare rarer normal normal normal)),
      "game/modoptions/teamcolors_anonymous_mode" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/multiplier_shieldpower" => Enum.random(~w(1 1 1 2 3 4)),
      "game/modoptions/disable_fogofwar" => Enum.random(~w(0 0 0 1)),
      "game/modoptions/assistdronesenabled" =>
        Enum.random(~w(pve_only pve_only pve_only enabled)),
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

    unit_list = armada_defences ++ armada_aa ++ cortex_defences ++ cortex_aa ++ scavt3 ++ legion_defences

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

    unit_list = armada_defences ++ armada_aa ++ cortex_defences ++ cortex_aa ++ scavt3 ++ legion_defences

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
    arm_scouts = ~w(armflea armfav armmark armseer armpeep armawac armrad armspy armarad armeyes armfrad armason armsehak)
    cor_scouts = ~w(corfav corvoyr corvrad corfink corawac corrad corarad corspy coreyes corfrad corason corhunt)
    Battle.disable_units(lobby_id, arm_scouts ++ cor_scouts)
    [
      "#{sender.name} has enabled the No Scouts meme. In this game you will not be able to create any scout, radar, or spy units; good luck!"
    ]
  end

  def handle_meme("hoversonly", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    new_options = %{"game/modoptions/tweakdefs" => "ZnVuY3Rpb24gZEMoU1QsIGNvcCkKY29wPWNvcCBvciB7fQpsb2NhbCBOVD17fQpjb3BbU1RdPU5UCmZvciBrLCB2IGluIHBhaXJzKFNUKSBkbwppZiB0eXBlKHYpPT0idGFibGUiIHRoZW4KaWYgTlRba109PW5pbCB0aGVuCk5UW2tdPXt9CmVuZApOVFtrXT1jb3Bbdl0gb3IgZEModiwgY29wKQplbHNlCk5UW2tdPXYKZW5kCmVuZApyZXR1cm4gTlQKZW5kCmxvY2FsIHVkID0gVW5pdERlZnMKdWQuYXJtY29tPWRDKHVkLmFybWNoKQp1ZC5jb3Jjb209ZEModWQuY29yY2gpCnVkLmxlZ2NvbT1kQyh1ZC5jb3JjaCkKZm9yIF8sIGEgaW4gcGFpcnMoe1sxXT17ImFybWNvbSIsImFybSIsImFybWNoIn0sWzJdPXsiY29yY29tIiwiY29yIiwiY29yY2gifSxbM109eyJsZWdjb20iLCJhcm0iLCJjb3JjaCJ9fSkgZG8KdWRbYVsxXV0uaWNvbnR5cGU9YVsyXS4uImNvbW1hbmRlciIKdWRbYVsxXV0ucmVjbGFpbWFibGU9ZmFsc2UKdWRbYVsxXV0ud29ya2VydGltZT0zMDAKdWRbYVsxXV0uY3VzdG9tcGFyYW1zPXsKCXVuaXRncm91cD0nYnVpbGRlcicsCglpc2NvbW1hbmRlciA9IHRydWUsCglwYXJhbHl6ZW11bHRpcGxpZXIgPSAwLjAyNSwKfQp1ZFthWzFdXS5zb3VuZHMudW5kZXJhdHRhY2s9Indhcm5pbmcyIgp1ZFthWzFdXS5zb3VuZHMuc2VsZWN0PXsKCVsxXT1hWzJdLi4iY29tc2VsIiwKfQp1ZFthWzFdXS5tZXRhbG1ha2U9Mgp1ZFthWzFdXS5tZXRhbHN0b3JhZ2U9NTAwCnVkW2FbMV1dLmVuZXJneW1ha2U9MjUKdWRbYVsxXV0uZW5lcmd5c3RvcmFnZT01MDAKZW5kCnVkLmxlZ2NvbS5tYXhkYW1hZ2U9MzcwMA"}
    cor_not_hover_fac = ~w(corsy corlab corvp corap coramsub corplat coravp coralab corasy coraap corgantuw corgant)
    arm_not_hover_fac = ~w(armsy armlab armvp armap armamsub armplat armalab armavp armaap armasy armshltx armshltxuw)
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
    new_options = %{"game/modoptions/faction_limiter" => "legion",
    "game/modoptions/experimentallegionfaction" => "1",
  }
    Battle.set_modoptions(lobby_id, new_options)
    [
      "#{sender.name} has enabled the Legion Only meme. Scorched Earth be upon us all; good luck!"
    ]
  end

  def handle_meme("randomizer", senderid, %{lobby_id: lobby_id} = _state) do
    sender = Account.get_user_by_id(senderid)
    new_options = %{"game/modoptions/tweakdefs" => "bG9jYWwgcG9vbHMgPSB7ClsxXSA9IHsiYXJtYXAiLCAiYXJtdnAiLCAiYXJtaHAiLCAiYXJtbGFiIiwgImNvcmFwIiwgImNvcnZwIiwgImNvcmhwIiwgImNvcmxhYiJ9LApbMl0gPSB7ImFybWFhcCIsICJhcm1hdnAiLCAiYXJtYWxhYiIsICJjb3JhYXAiLCAiY29yYXZwIiwgImNvcmFsYWIifSwKWzNdID0geyJhcm1maHAiLCAiYXJtcGxhdCIsICJhcm1zeSIsICJjb3JmaHAiLCAiY29ycGxhdCIsICJjb3JzeSJ9LApbNF0gPSB7ImFybXNobHR4IiwgImNvcmdhbnQifSwKWzVdID0geyJhcm1zaGx0eHV3IiwgImNvcmdhbnR1dyJ9LApbNl0gPSB7ImNvcmNvbSIsICJhcm1jb20ifSwKWzddID0geyJjb3JjYSIsICJjb3JjdiIsICJjb3JjayIsICJhcm1jYSIsICJhcm1jdiIsICJhcm1jayJ9LApbOF0gPSB7ImNvcmNoIiwgImFybWNoIiwgImFybWNzYSIsICJjb3Jjc2EiLCAiY29ybXVza3JhdCIsICJhcm1iZWF2ZXIifSwKWzldID0geyJjb3JhY2EiLCAiY29yYWNrIiwgImNvcmFjdiIsICJhcm1hY2EiLCAiYXJtYWNrIiwgImFybWFjdiJ9LApbMTBdID0geyJjb3JhY3N1YiIsICJhcm1hY3N1YiJ9LApbMTFdID0geyJjb3JtbHMiLCAiYXJtbWxzIiwgImNvcmNzIiwgImFybWNzIn0sClsxMl0gPSB7ImNvcm1sdiIsICJhcm1tbHYifSwKWzEzXSA9IHsiY29ybWFuZG8iLCAiY29yZmFzdCIsICJhcm1mYXJrIiwgImFybWRlY29tIiwgImNvcmRlY29tIn0KfQpmb3IgXywgc3dwIGluIHBhaXJzKHsKICAgIFsxXSA9IHsiYXJtYXAiLCJhcm1ocCJ9LAogICAgWzJdID0geyJhcm1hYXAiLCJhcm1ocCJ9LAogICAgWzNdID0geyJhcm1wbGF0IiwiYXJtZmhwIn0sCiAgICBbNF0gPSB7ImNvcmFwIiwiY29yaHAifSwKICAgIFs1XSA9IHsiY29yYWFwIiwiY29yaHAifSwKICAgIFs2XSA9IHsiY29ycGxhdCIsImNvcmZocCJ9LAogICAgWzddID0geyJsZWdhcCIsImNvcmZocCJ9LAogICAgWzhdID0geyJsZWdhYXAiLCJjb3JmaHAifSwKfSkgZG8KICAgIFVuaXREZWZzW3N3cFsxXV0ub2JqZWN0bmFtZSA9IFVuaXREZWZzW3N3cFsyXV0ub2JqZWN0bmFtZQogICAgVW5pdERlZnNbc3dwWzFdXS5zY3JpcHQgPSBVbml0RGVmc1tzd3BbMl1dLnNjcmlwdAogICAgVW5pdERlZnNbc3dwWzFdXS55YXJkbWFwID0gVW5pdERlZnNbc3dwWzJdXS55YXJkbWFwCiAgICBVbml0RGVmc1tzd3BbMV1dLmNvbGxpc2lvbnZvbHVtZW9mZnNldHMgPSBVbml0RGVmc1tzd3BbMl1dLmNvbGxpc2lvbnZvbHVtZW9mZnNldHMKICAgIFVuaXREZWZzW3N3cFsxXV0uY29sbGlzaW9udm9sdW1lc2NhbGVzID0gVW5pdERlZnNbc3dwWzJdXS5jb2xsaXNpb252b2x1bWVzY2FsZXMKICAgIFVuaXREZWZzW3N3cFsxXV0uY29sbGlzaW9udm9sdW1ldHlwZSA9IFVuaXREZWZzW3N3cFsyXV0uY29sbGlzaW9udm9sdW1ldHlwZQogICAgVW5pdERlZnNbc3dwWzFdXS5mb290cHJpbnR4ID0gVW5pdERlZnNbc3dwWzJdXS5mb290cHJpbnR4CiAgICBVbml0RGVmc1tzd3BbMV1dLmZvb3RwcmludHogPSBVbml0RGVmc1tzd3BbMl1dLmZvb3RwcmludHoKZW5kCmxvY2FsIGZ1bmN0aW9uIGFkZChhZGRUaGlzLCB0b1RoaXMpCiAgICBmb3IgaSA9IDEsICNhZGRUaGlzIGRvCiAgICAgICAgU3ByaW5nLkVjaG8oYWRkVGhpc1tpXSkKICAgICAgICBwb29sc1t0b1RoaXNdWyNwb29sc1t0b1RoaXNdKzFdID0gYWRkVGhpc1tpXQogICAgZW5kCmVuZAppZiBTcHJpbmcuR2V0TW9kT3B0aW9ucygpLmV4cGVyaW1lbnRhbGxlZ2lvbmZhY3Rpb24gPT0gdHJ1ZSB0aGVuCiAgICBhZGQoeyJsZWdhcCIsICJsZWd2cCIsICJsZWdsYWIifSwxKQogICAgYWRkKHsibGVnYWFwIiwgImxlZ2F2cCIsICJsZWdhbGFiIn0sIDIpCiAgICBwb29sc1s0XVsjcG9vbHNbNF0rMV0gPSAibGVnZ2FudCIKICAgIGFkZCh7ImxlZ2NvbSIsICJsZWdjb21sdmwyIiwgImxlZ2NvbWx2bDMiLCAibGVnY29tbHZsNCJ9LDYpCiAgICBhZGQoeyJsZWdjYSIsICJsZWdjayIsICJsZWdjdiJ9LDcpCiAgICBhZGQoeyJsZWdhY2EiLCAibGVnYWNrIiwgImxlZ2FjdiJ9LDkpCmVuZApsb2NhbCBmdW5jdGlvbiBjb250YWlucyhuYW1lLCBsaXN0KQogICAgZm9yIGksIG5tIGluIHBhaXJzKGxpc3QpIGRvCiAgICAgICAgaWYgbm0gPT0gbmFtZSB0aGVuCiAgICAgICAgICAgIHJldHVybiB0cnVlCiAgICAgICAgZW5kCiAgICBlbmQKICAgIHJldHVybiBmYWxzZQplbmQKZm9yIF8sIHBvb2wgaW4gcGFpcnMocG9vbHMpIGRvCiAgICBsb2NhbCB0b3RhbFVuaXRQb29sID0ge30KICAgIGZvciBfLCBuYW1lIGluIHBhaXJzKHBvb2wpIGRvCiAgICAgICAgbG9jYWwgYm8gPSBVbml0RGVmc1tuYW1lXS5idWlsZG9wdGlvbnMKICAgICAgICBmb3IgaSA9IDEsICNibyBkbwogICAgICAgICAgICB0b3RhbFVuaXRQb29sWyN0b3RhbFVuaXRQb29sKzFdID0gYm9baV0KICAgICAgICAgICAgYm9baV0gPSBuaWwKICAgICAgICBlbmQKICAgIGVuZAogICAgZm9yIGksIG5hbWUgaW4gcGFpcnModG90YWxVbml0UG9vbCkgZG8KICAgICAgICBsb2NhbCBmYWMgPSBwb29sW21hdGgucmFuZG9tKDEsICNwb29sKV0KICAgICAgICBsb2NhbCBibyA9IFVuaXREZWZzW2ZhY10uYnVpbGRvcHRpb25zCiAgICAgICAgbG9jYWwgbGltID0gMAogICAgICAgIHdoaWxlIGNvbnRhaW5zKG5hbWUsIGJvKSBkbwogICAgICAgICAgICBmYWMgPSBwb29sW21hdGgucmFuZG9tKDEsICNwb29sKV0KICAgICAgICAgICAgYm8gPSBVbml0RGVmc1tmYWNdLmJ1aWxkb3B0aW9ucwogICAgICAgICAgICBsaW0gPSBsaW0gKyAxCiAgICAgICAgZW5kCiAgICAgICAgYm9bI2JvKzFdID0gdG90YWxVbml0UG9vbFtpXQogICAgZW5kCmVuZA",
    "game/modoptions/experimentalextraunits" => "0",
  }
    Battle.set_modoptions(lobby_id, new_options)
    [
      "#{sender.name} has enabled the unsanitized Randomizer meme. Get ready to roll dices, a lot; good luck!"
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
      "game/modoptions/teamcolors_anonymous_mode" => "0",
      "game/modoptions/multiplier_shieldpower" => "1",
      "game/modoptions/disable_fogofwar" => "0",
      "game/modoptions/assistdronesenabled" => "pve_only",
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
