defmodule Teiserver.Bridge.DiscordMessageCleanup do
  @moduledoc """
  Handles deletion of bridged Discord messages for a given user.

  Used when a user is de-bridged via moderation — allows moderators to also
  remove the user's recent Discord messages that were bridged from Teiserver.
  """

  alias Teiserver.{Chat, Communication, Config}
  alias Teiserver.Data.Types, as: T
  require Logger

  @doc """
  Deletes bridged Discord messages sent by `user_id` in the last `hours` hours.

  Only messages that have a `discord_message_id` (i.e., were successfully bridged)
  are targeted. Returns `{:ok, deleted_count}` with the number of messages
  successfully deleted from Discord.
  """
  @spec delete_user_bridged_messages(T.userid(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def delete_user_bridged_messages(user_id, hours) when is_integer(hours) and hours > 0 do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    messages =
      Chat.list_room_messages(
        search: [
          user_id: user_id,
          inserted_after: cutoff,
          has_discord_message_id: true
        ],
        order_by: "Newest first",
        limit: 500
      )

    channel_lookup = get_channel_lookup()

    deleted_count =
      messages
      |> Enum.map(fn msg ->
        channel_id = Map.get(channel_lookup, msg.chat_room)

        if channel_id && msg.discord_message_id do
          case Communication.delete_discord_message(channel_id, msg.discord_message_id) do
            {:ok, _} ->
              1

            {:error, reason} ->
              Logger.warning(
                "Failed to delete Discord message #{msg.discord_message_id}: #{inspect(reason)}"
              )

              0

            _ ->
              # Nostrum returns {:ok} on success for delete, handle both forms
              1
          end
        else
          0
        end
      end)
      |> Enum.sum()

    Logger.info(
      "Deleted #{deleted_count}/#{length(messages)} bridged Discord messages for user #{user_id} (last #{hours}h)"
    )

    {:ok, deleted_count}
  end

  def delete_user_bridged_messages(_user_id, _hours), do: {:ok, 0}

  @doc """
  Returns a map of room_name => discord_channel_id from the site config cache.
  """
  @spec get_channel_lookup() :: %{String.t() => non_neg_integer()}
  def get_channel_lookup do
    [
      "teiserver.Discord channel #main",
      "teiserver.Discord channel #newbies",
      "teiserver.Discord channel #promote"
    ]
    |> Enum.map(fn key ->
      channel_id = Config.get_site_config_cache(key)

      if channel_id do
        [_, room] = String.split(key, "#")
        {room, channel_id}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end
end
