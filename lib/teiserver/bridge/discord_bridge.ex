defmodule Teiserver.Bridge.DiscordBridge do
  @moduledoc """
  This is the module that receives discord events and passes them to the rest of Teiserver.
  """

  # use Alchemy.Cogs
  use Alchemy.Events
  alias Teiserver.{Account, Room, Coordinator}
  alias Teiserver.Bridge.{BridgeServer, MessageCommands, ChatCommands}
  alias Central.{Config, Logging}
  alias Central.Account.{Report, ReportLib}
  alias Central.Helpers.TimexHelper
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
        Central.cache_put(:discord_bridge_dm_cache, dm_channel.id, recipient["id"])
        nil

      _ -> nil
    end
    :ok
  end

  @spec recv_message(atom | %{:attachments => any, optional(any) => any}) :: nil | :ok
  def recv_message(%Alchemy.Message{channel_id: channel_id, content: "$" <> content} = message) do
    dm_sender = Central.cache_get(:discord_bridge_dm_cache, channel_id)

    if dm_sender != nil do
      MessageCommands.handle(message)
    else
      ChatCommands.handle(message)
    end
  end

  def recv_message(%Alchemy.Message{author: author, channel_id: channel_id, attachments: [], content: content} = message) do
    room = bridge_channel_to_room(channel_id)
    dm_sender = Central.cache_get(:discord_bridge_dm_cache, channel_id)

    cond do
      author.username == Application.get_env(:central, DiscordBridge)[:bot_name] ->
        nil

      dm_sender != nil ->
        MessageCommands.handle(message)

      room == "moderation-reports" ->
        nil

      room == "moderation-actions" ->
        nil

      String.contains?(content, "http:") ->
        nil

      String.contains?(content, "https:") ->
        nil

      Config.get_site_config_cache("teiserver.Bridge from discord") == false ->
        nil

      room != nil ->
        do_reply(message)

      true ->
        nil
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

  @spec create_report(Report.t()) :: any
  def create_report(report) do
    chan_result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderation-reports" end)

    chan = case chan_result do
      [{chan, _}] -> chan
      _ -> nil
    end

    if chan do
      report = Account.get_report!(report.id, preload: [:reporter, :target])
      if report.response_action == nil do
        # It's a fresh report, we handle it as a report creation
        report_creation(report, chan)
      else
        # This was created as a whole thing, that said if it's the coordinator
        # then we don't bridge it
        if report.responder_id != Coordinator.get_coordinator_userid() do
          report_updated(report, :respond)
        end
      end
    end
  end

  # This is called from create_report and is just a way to handle that specific instance
  defp report_creation(report, chan) do
    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    url = "https://#{host}/teiserver/admin/user/#{report.target_id}#reports_tab"

    msg = "#{report.target.name} was reported by #{report.reporter.name} for reason #{report.reason} - #{url}"

    Alchemy.Client.send_message(
      chan,
      "Moderation report: #{msg}",
      []# Options
    )
  end

  @spec report_updated(Report.t(), :create | :respond | :update) :: :ok
  def report_updated(report, :create) do
    if report.response_text != nil do
      report_updated(report, :respond)
    else
      :ok
    end
  end

  def report_updated(%{response_action: nil}, :respond), do: :ok
  def report_updated(%{response_action: "Ignore report"}, :respond), do: :ok
  def report_updated(%{restrictions: []}, :respond), do: :ok
  def report_updated(report, :respond) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderation-actions" end)

    chan = case result do
      [{chan, _}] -> chan
      _ -> nil
    end

    skip_message = cond do
      Enum.empty?(report.action_data["restriction_list"]) -> true
      true -> false
    end

    if chan != nil and not skip_message do
      report = Account.get_report!(report.id, preload: [:target])
      past_tense = ReportLib.past_tense(report.response_action)

      if past_tense != nil do
        until = if report.expires do
          "Until: " <> TimexHelper.date_to_str(report.expires, format: :hms_dmy) <> " (UTC)"
        else
          "Permanent"
        end

        {restrictions, action} = if not Enum.empty?(report.action_data["restriction_list"]) do
          restriction_string = report.action_data["restriction_list"]
            |> Enum.join(", ")

          {"Restriction(s): #{restriction_string}", "action"}
        else
          {"", "warning"}
        end

        followup = if report.followup != nil do
          "If the behaviour continues, a follow up of #{report.followup} may be employed"
        else
          ""
        end

        msg = [
          "----------------------",
          "Moderation #{action} for #{report.target.name}",
          "Reason: #{report.response_text}",
          restrictions,
          until,
          followup,
          "----------------------"
        ]
        |> Enum.join("\n")
        |> String.replace("\n\n", "\n")

        Alchemy.Client.send_message(
          chan,
          msg,
          []# Options
        )
      end
    end
    :ok
  end

  def report_updated(report, :update) do
    # Give time for the audit log to be added
    :timer.sleep(200)

    result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderation-actions" end)

    chan = case result do
      [{chan, _}] -> chan
      _ -> nil
    end

    if chan do
      log = Logging.get_audit_log(nil, search: [
          action: "Account:Updated report",
          details_equal: {"report", report.id |> to_string}
        ],
        order: "Newest first",
        limit: 1
      )

      expires_now = Timex.compare(Timex.now() |> Timex.shift(minutes: 1), report.expires) == 1

      report = Account.get_report!(report.id, preload: [:target])
      until = TimexHelper.date_to_str(report.expires, format: :hms_dmy) <> " (UTC)"

      restriction_change = case log.details["restriction_change"] do
        "expanded" -> "Restrictions expanded to: #{report.action_data["restriction_list"] |> Enum.join(", ")}"
        "reduced" -> "Restrictions reduced to: #{report.action_data["restriction_list"] |> Enum.join(", ")}"
        "no change" -> nil
        "altered" -> "Restrictions altered to: #{report.action_data["restriction_list"] |> Enum.join(", ")}"
        _ -> nil
      end

      response_change = case log.details["response_change"] do
        nil -> nil
        r -> "Updated reason for action: #{r}"
      end

      message = cond do
        expires_now == true ->
          [
            "----------------------",
            "#{report.target.name} had moderation action reversed",
            response_change,
            restriction_change,
            "Reason for update: #{log.details["reason"]}",
            "----------------------"
          ]
          |> Enum.filter(fn i -> i != nil end)
          |> Enum.join("\n")

        log.details["duration"] == "Sooner" ->
          [
            "----------------------",
            "#{report.target.name} had their penalty duration reduced",
            "Now expires: #{until}",
            response_change,
            restriction_change,
            "Reason for update: #{log.details["reason"]}",
            "----------------------"
          ]
          |> Enum.filter(fn i -> i != nil end)
          |> Enum.join("\n")

        log.details["duration"] == "No change" ->
          [
            "----------------------",
            "#{report.target.name} had their penalty altered",
            response_change,
            restriction_change,
            "Reason for update: #{log.details["reason"]}",
            "----------------------"
          ]
          |> Enum.filter(fn i -> i != nil end)
          |> Enum.join("\n")

        true ->
          [
            "----------------------",
            "#{report.target.name} had their penalty duration extended",
            "Now expires: #{until}",
            response_change,
            restriction_change,
            "Reason for update: #{log.details["reason"]}",
            "----------------------"
          ]
          |> Enum.filter(fn i -> i != nil end)
          |> Enum.join("\n")
      end

      Alchemy.Client.send_message(
        chan,
        message,
        []# Options
      )
    end
    :ok
  end
  def report_updated(_, :silent), do: :ok

  defp do_reply(%Alchemy.Message{author: author, content: content, channel_id: channel_id, mentions: mentions}) do
    # Mentions come through encoded in a way we don't want to preserve, this substitutes them
    new_content = mentions
    |> Enum.reduce(content, fn (m, acc) ->
      String.replace(acc, "<@!#{m.id}>", m.username)
    end)
    |> String.replace(~r/<#[0-9]+> ?/, "")
    |> convert_emoticons
    |> String.split("\n")

    bridge_user_id = BridgeServer.get_bridge_userid()
    from_id = bridge_user_id

    # Temporarily disabled as the bridge echos itself
    # from_id = case User.get_userid_by_discord_id(author.id) do
    #   nil ->
    #     bridge_user_id
    #   userid ->
    #     case Client.get_client_by_id(userid) do
    #       nil ->
    #         bridge_user_id
    #       _ ->
    #         userid
    #     end
    # end

    message = if from_id == bridge_user_id do
      new_content
      |> Enum.map(fn row ->
        "#{author.username}: #{row}"
      end)
    else
      new_content
    end

    room = bridge_channel_to_room(channel_id)
    Room.send_message(from_id, room, message)
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
end
