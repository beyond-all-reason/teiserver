defmodule Teiserver.Bridge.DiscordBridge do
  # use Alchemy.Cogs
  use Alchemy.Events
  alias Teiserver.{Account, Room}
  alias Central.Config
  alias Central.Account.ReportLib
  alias Central.Helpers.TimexHelper
  alias Teiserver.Bridge.BridgeServer
  require Logger

  # Discord message ping: <@userid>

  @emoticon_map %{
    "🙂" => ":)",
    "😒" => ":s",
    "😦" => ":(",
    "😛" => ":p",
    "😄" => ":D",
  }

  @extra_text_emoticons %{
    ":S" => "😒",
    ":P" => "😛",
  }

  @text_to_emoticon_map @emoticon_map
  |> Map.new(fn {k, v} -> {v, k} end)
  |> Map.merge(@extra_text_emoticons)

  @spec get_text_to_emoticon_map() :: Map.t()
  def get_text_to_emoticon_map, do: @text_to_emoticon_map

  Events.on_DMChannel_create(:new_dm_channel)
  Events.on_message(:recv_message)

  def new_dm_channel(dm_channel) do
    case dm_channel.recipients do
      [recipient] ->
        ConCache.put(:discord_bridge_dm_cache, dm_channel.id, recipient["id"])

      _ -> nil
    end
    :ok
  end

  @spec recv_message(atom | %{:attachments => any, optional(any) => any}) :: nil | :ok
  def recv_message(%Alchemy.Message{author: author, channel_id: channel_id, attachments: []} = message) do
    room = bridge_channel_to_room(channel_id)
    dm_sender = ConCache.get(:discord_bridge_dm_cache, channel_id)

    cond do
      author.username == Application.get_env(:central, DiscordBridge)[:bot_name] ->
        nil

      dm_sender != nil ->
        receive_dm(message)

      Config.get_site_config_cache("teiserver.Bridge from discord") == false ->
        nil

      room == nil ->
        nil

      room == "moderation-reports" ->
        nil

      room == "moderation-actions" ->
        nil

      true ->
        do_reply(message)
        :ok
    end
  end

  def recv_message(message) do
    cond do
      message.attachments != [] ->
        nil

      # We expected to be able to handle it but didn't, what's happening?
      true ->
        Logger.debug("Unhandled DiscordBridge event: #{Kernel.inspect message}")
    end
  end

  def moderator_report(report_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderation-reports" end)

    chan = case result do
      [{chan, _}] -> chan
      _ -> nil
    end

    if chan do
      report = Account.get_report!(report_id, preload: [:reporter, :target])
      if report.response_action == nil do
        host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
        url = "https://#{host}/teiserver/admin/user/#{report.target_id}#reports_tab"

        msg = "#{report.target.name} was reported by #{report.reporter.name} for reason #{report.reason} - #{url}"

        Alchemy.Client.send_message(
          chan,
          "Moderation report: #{msg}",
          []# Options
        )
      else
        # This was created as a whole thing
        moderator_action(report_id)
      end
    end
  end

  def moderator_action(report_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderation-actions" end)

    chan = case result do
      [{chan, _}] -> chan
      _ -> nil
    end

    if chan do
      report = Account.get_report!(report_id, preload: [:responder, :target])
      past_tense = ReportLib.past_tense(report.response_action)

      if past_tense != nil do
        until = if report.expires do
          "until " <> TimexHelper.date_to_str(report.expires, format: :hms_dmy) <> " (UTC)"
        else
          "Permanent"
        end

        msg = "#{report.target.name} was #{past_tense} by #{report.responder.name} for reason #{report.response_text}, #{until}"

        Alchemy.Client.send_message(
          chan,
          "Moderation action: #{msg}",
          []# Options
        )
      end
    end
  end

  defp do_reply(%Alchemy.Message{author: author, content: content, channel_id: channel_id, mentions: mentions}) do
    # Mentions come through encoded in a way we don't want to preserve, this substitutes them
    new_content = mentions
    |> Enum.reduce(content, fn (m, acc) ->
      String.replace(acc, "<@!#{m.id}>", m.username)
    end)
    |> String.replace(~r/<#[0-9]+> ?/, "")
    |> convert_emoticons
    |> String.split("\n")
    |> Enum.map(fn row ->
      "#{author.username}: #{row}"
    end)

    from_id = BridgeServer.get_bridge_userid()
    room = bridge_channel_to_room(channel_id)
    Room.send_message(from_id, room, new_content)
  end

  defp convert_emoticons(msg) do
    msg
    |> String.replace(Map.keys(@emoticon_map), fn emoji -> @emoticon_map[emoji] end)
  end

  defp bridge_channel_to_room(channel_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
    |> Enum.filter(fn {chan, _room} -> chan == channel_id end)

    case result do
      [{_, room}] -> room
      _ -> nil
    end
  end

  def receive_dm(%Alchemy.Message{author: _author, channel_id: channel, content: _content, attachments: []} = _message) do
    Alchemy.Client.send_message(
      channel,
      "Unfortunately I don't understand that command",
      []# Options
    )
  end
end
