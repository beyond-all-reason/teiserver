defmodule Teiserver.Protocols.Spring do
  alias Teiserver.BitParse
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Protocols.SpringOut

  @spec protocol_in :: Teiserver.Protocols.SpringIn
  def protocol_in(), do: SpringIn

  @spec protocol_out :: Teiserver.Protocols.SpringOut
  def protocol_out(), do: SpringOut

  @spec parse_client_status(String.t()) :: Map.t()
  def parse_client_status(status_str) do
    status_bits =
      BitParse.parse_bits(status_str, 7)
      |> Enum.reverse()

    [in_game, away, r1, r2, r3, mod, bot] = status_bits

    %{
      in_game: in_game == 1,
      away: away == 1,
      rank: [r3, r2, r1] |> Integer.undigits(2),
      moderator: mod == 1,
      bot: bot == 1
    }
  end

  @spec create_client_status(Map.t()) :: Integer.t()
  def create_client_status(client) do
    [r1, r2, r3] = BitParse.parse_bits("#{client.rank || 1}", 3)

    [
      if(client.in_game, do: 1, else: 0),
      if(client.away, do: 1, else: 0),
      r3,
      r2,
      r1,
      if(client.moderator, do: 1, else: 0),
      if(client.bot, do: 1, else: 0)
    ]
    |> Enum.reverse()
    |> Integer.undigits(2)
  end

  # b0 = undefined (reserved for future use)
  # b1 = ready (0=not ready, 1=ready)
  # b2..b5 = team no. (from 0 to 15. b2 is LSB, b5 is MSB)
  # b6..b9 = ally team no. (from 0 to 15. b6 is LSB, b9 is MSB)
  # b10 = mode (0 = spectator, 1 = normal player)
  # b11..b17 = handicap (7-bit number. Must be in range 0..100). Note: Only host can change handicap values of the players in the battle (with HANDICAP command). These 7 bits are always ignored in this command. They can only be changed using HANDICAP command.
  # b18..b21 = reserved for future use (with pre 0.71 versions these bits were used for team color index)
  # b22..b23 = sync status (0 = unknown, 1 = synced, 2 = unsynced)
  # b24..b27 = side (e.g.: arm, core, tll, ... Side index can be between 0 and 15, inclusive)
  # b28..b31 = undefined (reserved for future use)
  @spec parse_battle_status(String.t()) :: Map.t()
  def parse_battle_status(status) do
    status_bits =
      BitParse.parse_bits(status, 32)
      |> Enum.reverse()

    [
      # Undefined
      _,
      ready,
      # team number
      t1,
      t2,
      t3,
      t4,
      # ally team number
      a1,
      a2,
      a3,
      a4,
      player,
      # Handicap
      h1,
      h2,
      h3,
      h4,
      h5,
      h6,
      h7,
      # Undefined
      _,
      # Undefined
      _,
      # Undefined
      _,
      # Undefined
      _,
      sync1,
      sync2,
      side1,
      side2,
      side3,
      side4,
      # Undefined
      _,
      # Undefined
      _,
      # Undefined
      _,
      # Undefined
      _
    ] = status_bits

    # Team is the player
    # Ally team is the team the player is on
    %{
      ready: ready == 1,
      handicap: [h7, h6, h5, h4, h3, h2, h1] |> Integer.undigits(2),
      team_number: [t4, t3, t2, t1] |> Integer.undigits(2),
      ally_team_number: [a4, a3, a2, a1] |> Integer.undigits(2),
      player: player == 1,
      sync: [sync2, sync1] |> Integer.undigits(2),
      side: [side4, side3, side2, side1] |> Integer.undigits(2)
    }
  end

  @spec create_battle_status(Map.t()) :: Integer.t()
  def create_battle_status(client) do
    [t4, t3, t2, t1] = BitParse.parse_bits("#{client.team_number}", 4)
    [a4, a3, a2, a1] = BitParse.parse_bits("#{client.ally_team_number}", 4)
    [h7, h6, h5, h4, h3, h2, h1] = BitParse.parse_bits("#{client.handicap}", 7)
    [sync2, sync1] = BitParse.parse_bits("#{client.sync}", 2)
    [side4, side3, side2, side1] = BitParse.parse_bits("#{client.side}", 4)

    [
      0,
      if(client.ready, do: 1, else: 0),
      t1,
      t2,
      t3,
      t4,
      a1,
      a2,
      a3,
      a4,
      if(client.player, do: 1, else: 0),
      h1,
      h2,
      h3,
      h4,
      h5,
      h6,
      h7,
      0,
      0,
      0,
      0,
      sync1,
      sync2,
      side1,
      side2,
      side3,
      side4,
      0,
      0,
      0,
      0
    ]
    |> Enum.reverse()
    |> Integer.undigits(2)
  end

  @spec format_log(String.t()) :: String.t()
  def format_log(nil), do: ""
  def format_log(s) do
    s
    |> String.trim()
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "~~")
    |> String.slice(0..100)
  end
end
