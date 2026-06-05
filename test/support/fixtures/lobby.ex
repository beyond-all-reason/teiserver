defmodule Teiserver.LobbyFixtures do
  @moduledoc false

  alias Teiserver.Lobby.LobbyLib

  @type invalid_name_kind :: :empty | :too_long | :invalid_char | :flagged
  @spec invalid_name() :: String.t()
  @spec invalid_name(invalid_name_kind()) :: String.t()
  def invalid_name(kind \\ :empty) do
    case kind do
      :empty ->
        ""

      :too_long ->
        String.duplicate("a", LobbyLib.max_name_length() + 1)

      :invalid_char ->
        "invalid: =="

      :flagged ->
        "cun7"
    end
  end

  def invalid_names do
    [
      invalid_name(:empty),
      invalid_name(:too_long),
      invalid_name(:invalid_char),
      invalid_name(:flagged)
    ]
  end
end
