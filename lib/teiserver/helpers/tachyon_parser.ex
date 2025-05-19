defmodule Teiserver.Helpers.TachyonParser do
  @moduledoc """
  To group generally useful parsing function related to tachyon that can be
  used for both players and autohost
  """
  alias Teiserver.Data.Types, as: T

  @spec parse_user_ids([String.t()]) :: {valid_ids :: [T.userid()], invalid_ids :: [String.t()]}
  def parse_user_ids(raw_ids) do
    Enum.reduce(raw_ids, {[], []}, fn raw_id, {ok, invalid} ->
      case Integer.parse(raw_id) do
        {id, ""} -> {[id | ok], invalid}
        _ -> {ok, [raw_id | invalid]}
      end
    end)
  end

  @spec parse_user_id(String.t()) :: {:ok, T.userid()} | {:error, :invalid_id}
  def parse_user_id(raw) do
    case Integer.parse(raw) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end
end
