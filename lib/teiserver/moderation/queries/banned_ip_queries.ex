defmodule Teiserver.Moderation.BannedIPQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.BannedIP

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec banned_ips() :: t()
  def banned_ips do
    from(banned_ips in BannedIP, as: :banned_ips)
  end

  @spec where_id(t(), BannedIP.id()) :: t()
  def where_id(query, id) do
    from banned_ips in query,
      where: banned_ips.id == ^id
  end

  @spec where_cidr_like(t(), nil | String.t()) :: t()
  def where_cidr_like(query, nil), do: query

  def where_cidr_like(query, cidr) do
    cidr = "%" <> cidr <> "%"

    from banned_ips in query,
      where: ilike(banned_ips.cidr, ^cidr)
  end

  @spec order_by_severity(t(), :asc | :desc) :: t()
  def order_by_severity(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_ips in query, order_by: [asc: banned_ips.severity])
    else
      from(banned_ips in query, order_by: [desc: banned_ips.severity])
    end
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_ips in query, order_by: [asc: banned_ips.inserted_at])
    else
      from(banned_ips in query, order_by: [desc: banned_ips.inserted_at])
    end
  end

  @spec order_by_cidr(t(), :asc | :desc) :: t()
  def order_by_cidr(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_ips in query, order_by: [asc: banned_ips.cidr])
    else
      from(banned_ips in query, order_by: [desc: banned_ips.cidr])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
  def order_by_from_string(query, "Alphabetical (A-Z)"), do: order_by_cidr(query, :asc)
  def order_by_from_string(query, "Alphabetical (Z-A)"), do: order_by_cidr(query, :desc)
end
