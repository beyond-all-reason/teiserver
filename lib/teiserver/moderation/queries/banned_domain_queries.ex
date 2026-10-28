defmodule Teiserver.Moderation.BannedDomainQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.BannedDomain

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec banned_domains() :: t()
  def banned_domains do
    from(banned_domains in BannedDomain, as: :banned_domains)
  end

  @spec where_id(t(), BannedDomain.id()) :: t()
  def where_id(query, id) do
    from banned_domains in query,
      where: banned_domains.id == ^id
  end

  @spec where_domain_like(t(), nil | String.t()) :: t()
  def where_domain_like(query, nil), do: query

  def where_domain_like(query, domain) do
    domain = "%" <> domain <> "%"

    from banned_domains in query,
      where: ilike(banned_domains.domain, ^domain)
  end

  @spec order_by_severity(t(), :asc | :desc) :: t()
  def order_by_severity(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_domains in query, order_by: [asc: banned_domains.severity])
    else
      from(banned_domains in query, order_by: [desc: banned_domains.severity])
    end
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_domains in query, order_by: [asc: banned_domains.inserted_at])
    else
      from(banned_domains in query, order_by: [desc: banned_domains.inserted_at])
    end
  end

  @spec order_by_domain(t(), :asc | :desc) :: t()
  def order_by_domain(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_domains in query, order_by: [asc: banned_domains.domain])
    else
      from(banned_domains in query, order_by: [desc: banned_domains.domain])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
  def order_by_from_string(query, "Alphabetical (A-Z)"), do: order_by_domain(query, :asc)
  def order_by_from_string(query, "Alphabetical (Z-A)"), do: order_by_domain(query, :desc)
end
