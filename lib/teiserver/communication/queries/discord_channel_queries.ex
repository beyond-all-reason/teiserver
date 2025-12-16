defmodule Teiserver.Communication.DiscordChannelQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Communication.DiscordChannel

  # Queries
  @spec query_discord_channels(list) :: Ecto.Query.t()
  def query_discord_channels(args) do
    query = from(discord_channels in DiscordChannel)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

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

  @spec do_order_by(Ecto.Query.t(), list | String.t() | nil) :: Ecto.Query.t()
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
end
