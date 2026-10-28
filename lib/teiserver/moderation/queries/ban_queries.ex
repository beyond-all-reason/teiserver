defmodule Teiserver.Moderation.BanQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.Ban

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec bans() :: t()
  def bans do
    from(bans in Ban, as: :bans)
  end

  @spec where_id(t(), Ban.id()) :: t()
  def where_id(query, id) do
    from [bans: bans] in query,
      where: bans.id == ^id
  end

  def where_inserted_after(query, nil), do: query

  def where_inserted_after(query, %Date{} = date) do
    timestamp = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where_inserted_after(query, timestamp)
  end

  def where_inserted_after(query, %DateTime{} = timestamp) do
    from [bans: bans] in query,
      where: bans.inserted_at > ^timestamp
  end

  def where_inserted_before(query, nil), do: query

  def where_inserted_before(query, %Date{} = date) do
    timestamp = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where_inserted_before(query, timestamp)
  end

  def where_inserted_before(query, %DateTime{} = timestamp) do
    from [bans: bans] in query,
      where: bans.inserted_at < ^timestamp
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from([bans: bans] in query, order_by: [asc: bans.inserted_at])
    else
      from([bans: bans] in query, order_by: [desc: bans.inserted_at])
    end
  end

  @spec order_by_expires(t(), :asc | :desc) :: t()
  def order_by_expires(query, direction \\ :asc) do
    if direction == :asc do
      from([bans: bans] in query, order_by: [asc: bans.expires])
    else
      from([bans: bans] in query, order_by: [desc: bans.expires])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
  def order_by_from_string(query, "Expires earliest"), do: order_by_expires(query, :asc)
  def order_by_from_string(query, "Expires latest"), do: order_by_expires(query, :desc)
end
