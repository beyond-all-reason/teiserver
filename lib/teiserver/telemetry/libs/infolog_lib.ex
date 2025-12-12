defmodule Teiserver.Telemetry.InfologLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Telemetry.Infolog

  # Functions
  @spec colours :: atom
  def colours(), do: :success2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-barcode"

  # Queries
  @spec query_infologs() :: Ecto.Query.t()
  def query_infologs do
    from(infologs in Infolog)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from infologs in query,
      where: infologs.id == ^id
  end

  def _search(query, :engine, value) do
    from infologs in query,
      where: fragment("? ->> ? ILIKE ?", infologs.metadata, "engineversion", ^"%#{value}%")
  end

  def _search(query, :game, value) do
    from infologs in query,
      where: fragment("? ->> ? = ?", infologs.metadata, "gameversion", ^value)
  end

  def _search(query, :shorterror, value) do
    from infologs in query,
      where: fragment("? ->> ? ILIKE ?", infologs.metadata, "shorterror", ^"%#{value}%")
  end

  def _search(query, :log_type, "Any"), do: query

  def _search(query, :log_type, log_type) do
    from infologs in query,
      where: infologs.log_type == ^log_type
  end

  def _search(query, :user_id, user_id) do
    from infologs in query,
      where: infologs.user_id == ^user_id
  end

  def _search(query, :id_list, id_list) do
    from infologs in query,
      where: infologs.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from infologs in query,
      where: between(infologs.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from infologs in query,
      where: ilike(infologs.name, ^ref_like)
  end

  def _search(query, :inserted_after, timestamp) do
    from infologs in query,
      where: infologs.timestamp >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from infologs in query,
      where: infologs.timestamp < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from infologs in query,
      order_by: [desc: infologs.timestamp]
  end

  def order_by(query, "Oldest first") do
    from infologs in query,
      order_by: [asc: infologs.timestamp]
  end

  def order_by(query, "Smallest first") do
    from infologs in query,
      order_by: [asc: infologs.size]
  end

  def order_by(query, "Largest first") do
    from infologs in query,
      order_by: [desc: infologs.size]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  @spec _preload_users(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_users(query) do
    from infologs in query,
      left_join: users in assoc(infologs, :user),
      preload: [user: users]
  end
end
