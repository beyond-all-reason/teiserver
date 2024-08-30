defmodule Teiserver.Protocols.Spring do
  @moduledoc false
  alias Teiserver.BitParse
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Protocols.SpringOut

  @spec protocol_in :: Teiserver.Protocols.SpringIn
  def protocol_in(), do: SpringIn

  @spec protocol_out :: Teiserver.Protocols.SpringOut
  def protocol_out(), do: SpringOut

  @spec parse_client_status(String.t()) :: map()
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

  @spec create_client_status(map()) :: Integer.t()
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
  # b18..b21 = reserved for future use (with pre 0.71 versions these bits were used for team colour index) Experimental: Use these for team no. extension (16->256)
  # b22..b23 = sync status (0 = unknown, 1 = synced, 2 = unsynced)
  # b24..b27 = side (e.g.: arm, core, tll, ... Side index can be between 0 and 15, inclusive)
  # b28..b31 = undefined (reserved for future use) Experimental: Use these for ally team no. extension (16->256)
  @spec parse_battle_status(String.t()) :: map()
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
      # Experimental extension for team no. > 16
      t5,
      t6,
      t7,
      t8,
      sync1,
      sync2,
      side1,
      side2,
      side3,
      side4,
      # Experimental extension for ally team no. > 16
      a5,
      a6,
      a7,
      a8
    ] = status_bits

    sync = [sync2, sync1] |> Integer.undigits(2)

    sync =
      case sync do
        1 ->
          %{
            game: 1,
            engine: 1,
            map: 1
          }

        2 ->
          %{
            game: 0,
            engine: 0,
            map: 0
          }

        0 ->
          %{
            bot: 1
          }
      end

    # Team is the player
    # Ally team is the team the player is on
    %{
      ready: ready == 1,
      handicap: [h7, h6, h5, h4, h3, h2, h1] |> Integer.undigits(2),
      player_number: [t8, t7, t6, t5, t4, t3, t2, t1] |> Integer.undigits(2),
      team_number: [a8, a7, a6, a5, a4, a3, a2, a1] |> Integer.undigits(2),
      player: player == 1,
      sync: sync,
      side: [side4, side3, side2, side1] |> Integer.undigits(2)
    }
  end

  @spec create_battle_status(map()) :: Integer.t()
  def create_battle_status(client) do
    sync_value = Map.get(client, :sync, %{})

    all_one =
      sync_value
      |> Enum.filter(fn {_key, value} -> value != 1 end)
      |> Enum.empty?()

    sync =
      cond do
        Map.get(sync_value, :bot, nil) == 1 -> 0
        all_one == true -> 1
        true -> 2
      end

    [t8, t7, t6, t5, t4, t3, t2, t1] = BitParse.parse_bits("#{client.player_number}", 8)
    [a8, a7, a6, a5, a4, a3, a2, a1] = BitParse.parse_bits("#{client.team_number}", 8)
    [h7, h6, h5, h4, h3, h2, h1] = BitParse.parse_bits("#{client.handicap}", 7)
    [sync2, sync1] = BitParse.parse_bits("#{sync}", 2)
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
      t5,
      t6,
      t7,
      t8,
      sync1,
      sync2,
      side1,
      side2,
      side3,
      side4,
      a5,
      a6,
      a7,
      a8
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

  @doc """
  Takes zipped and base64'd data and tries to extract it
  """
  def read_compressed_base64(raw_string) do
    case Base.url_decode64(raw_string) do
      {:ok, compressed_contents} ->
        case unzip(compressed_contents) do
          {:ok, contents} ->
            {:ok, contents}

          {:error, _} ->
            {:error, "unzip decode error"}
        end

      _ ->
        {:error, "base64 decode error"}
    end
  end

  def unzip(data) do
    try do
      result = :zlib.uncompress(data)
      {:ok, result}
    rescue
      _ ->
        {:error, :unzip_decompress}
    end
  end

  @spec decode_value(String.t()) :: {:ok, any} | {:error, String.t()}
  def decode_value(raw) do
    case Base.url_decode64(raw) do
      {:ok, string} ->
        case Jason.decode(string) do
          {:ok, json} ->
            {:ok, json}

          {:error, %Jason.DecodeError{position: position, data: _data}} ->
            {:error, "Json decode error at position #{position}"}
        end

      _ ->
        {:error, "Base64 decode error"}
    end
  end
end
