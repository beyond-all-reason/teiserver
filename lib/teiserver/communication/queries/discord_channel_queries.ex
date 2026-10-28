defmodule Teiserver.Communication.DiscordChannelQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Communication.DiscordChannel

  use TeiserverWeb, :queries

  @type t :: Query.t()

  # Queries
  @spec query_discord_channels(list) :: t()
  def query_discord_channels(args) do
    query = from(discord_channels in DiscordChannel)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
  end

  @spec do_where(t(), list | map | nil) :: t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(t(), atom(), any()) :: t()
  defp _where(query, _key, ""), do: query
  defp _where(query, _key, nil), do: query

  defp _where(query, :id, id) do
    from discord_channels in query,
      where: discord_channels.id == ^id
  end

  defp _where(query, :name, name) do
    from discord_channels in query,
      where: discord_channels.name == ^name
  end

  defp _where(query, :channel_id, channel_id) do
    from discord_channels in query,
      where: discord_channels.channel_id == ^channel_id
  end

  @spec do_order_by(t(), list | String.t() | nil) :: t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, orderings) when is_list(orderings) do
    orderings
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, ordering), do: do_order_by(query, [ordering])

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from discord_channels in query,
      order_by: [desc: discord_channels.inserted_at]
  end

  defp _order_by(query, "Oldest first") do
    from discord_channels in query,
      order_by: [asc: discord_channels.inserted_at]
  end

  defp _order_by(query, "Name (A-Z)") do
    from discord_channels in query,
      order_by: [asc: discord_channels.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from discord_channels in query,
      order_by: [desc: discord_channels.name]
  end

  # New format
  @spec discord_channels() :: t()
  def discord_channels do
    from(discord_channels in DiscordChannel, as: :discord_channels)
  end

  @spec where_id(t(), DiscordChannel.id()) :: t()
  def where_id(query, id) do
    from discord_channels in query,
      where: discord_channels.id == ^id
  end

  @spec where_name_like(t(), String.t()) :: t()
  def where_name_like(query, ""), do: query

  def where_name_like(query, search_term) do
    search_term = "%" <> search_term <> "%"

    from discord_channels in query,
      where: ilike(discord_channels.name, ^search_term)
  end

  @spec where_channel_id(t(), String.t() | number()) :: t()
  def where_channel_id(query, channel_id) do
    from discord_channels in query,
      where: discord_channels.channel_id == ^channel_id
  end

  @spec order_by_name(t(), :asc | :desc) :: t()
  def order_by_name(query, direction \\ :asc) do
    if direction == :asc do
      from(discord_channels in query, order_by: [asc: discord_channels.name])
    else
      from(discord_channels in query, order_by: [desc: discord_channels.name])
    end
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(discord_channels in query, order_by: [asc: discord_channels.inserted_at])
    else
      from(discord_channels in query, order_by: [desc: discord_channels.inserted_at])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Alphabetical (A-Z)"), do: order_by_name(query, :asc)
  def order_by_from_string(query, "Alphabetical (Z-A)"), do: order_by_name(query, :desc)
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
end
