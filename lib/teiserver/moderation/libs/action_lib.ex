defmodule Teiserver.Moderation.ActionLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.{Communication, Moderation}
  alias Teiserver.Moderation.Action
  alias Teiserver.Helper.TimexHelper

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-triangle-exclamation"

  @spec colour :: atom
  def colour, do: :primary

  @spec action_icon(String.t() | nil) :: String.t()
  def action_icon(nil), do: ""
  def action_icon("Report expired"), do: "fa-solid fa-clock"
  def action_icon("Ignore report"), do: "fa-solid fa-check-circle"
  def action_icon("Warn"), do: "fa-solid fa-triangle-exclamation"
  def action_icon("Restrict"), do: "fa-solid fa-do-not-enter"
  def action_icon("Mute"), do: "fa-solid fa-microphone-slash"
  def action_icon("Suspend"), do: "fa-solid fa-pause"
  def action_icon("Ban"), do: "fa-solid fa-ban"

  def action_icon("Smurf"), do: "fa-solid fa-copy"

  @spec make_favourite(map()) :: map()
  def make_favourite(action) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: action.id,
      item_type: "teiserver_moderation_action",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{action.target.name}",
      url: "/moderation/actions/#{action.id}"
    }
  end

  # Queries
  @spec query_actions() :: Ecto.Query.t()
  def query_actions do
    from(actions in Action)
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
    from actions in query,
      where: actions.id == ^id
  end

  def _search(query, :name, name) do
    from actions in query,
      where: actions.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from actions in query,
      where: actions.id in ^id_list
  end

  def _search(query, :target_id, target_id) do
    from actions in query,
      where: actions.target_id == ^target_id
  end

  def _search(query, :target_id_in, id_list) do
    from actions in query,
      where: actions.target_id in ^id_list
  end

  def _search(query, :in_restrictions, restrictions) do
    from actions in query,
      where: ^restrictions in actions.restrictions
  end

  def _search(query, :not_in_restrictions, restrictions) when is_list(restrictions) do
    from actions in query,
      where: not array_overlap_a_in_b(actions.restrictions, ^restrictions)
  end

  def _search(query, :expiry, "All"), do: query

  def _search(query, :expiry, "Completed only") do
    from actions in query,
      where: actions.expires < ^Timex.now()
  end

  def _search(query, :expiry, "Unexpired only") do
    from actions in query,
      where: actions.expires > ^Timex.now()
  end

  def _search(query, :expiry, "Unexpired not permanent") do
    years = Timex.now() |> Timex.shift(years: 100)

    from actions in query,
      where: actions.expires > ^Timex.now() and actions.expires < ^years
  end

  def _search(query, :expiry, "Permanent only") do
    years = Timex.now() |> Timex.shift(years: 100)

    from actions in query,
      where: actions.expires > ^years
  end

  def _search(query, :expiry, "All active") do
    from actions in query,
      where: actions.expires > ^Timex.now() or is_nil(actions.expires)
  end

  def _search(query, :inserted_after, datetime) do
    from actions in query,
      where: actions.inserted_at > ^datetime
  end

  def _search(query, :inserted_before, datetime) do
    from actions in query,
      where: actions.inserted_at < ^datetime
  end

  def _search(query, :discord_message_id, discord_message_id) do
    from actions in query,
      where: actions.discord_message_id == ^discord_message_id
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from actions in query,
      order_by: [asc: actions.name]
  end

  def order_by(query, "Name (Z-A)") do
    from actions in query,
      order_by: [desc: actions.name]
  end

  def order_by(query, "Most recently inserted first") do
    from actions in query,
      order_by: [desc: actions.inserted_at]
  end

  def order_by(query, "Oldest inserted first") do
    from actions in query,
      order_by: [asc: actions.inserted_at]
  end

  def order_by(query, "Earliest expiry first") do
    from actions in query,
      order_by: [asc: actions.expires]
  end

  def order_by(query, "Latest expiry first") do
    from actions in query,
      order_by: [desc: actions.expires]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :target in preloads, do: _preload_target(query), else: query
    query = if :report_groups in preloads, do: _preload_report_groups(query), else: query

    query =
      if :report_group_reports_and_reporters in preloads,
        do: _preload_report_group_reports_and_reporters(query),
        else: query

    query
  end

  @spec _preload_target(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_target(query) do
    from actions in query,
      left_join: targets in assoc(actions, :target),
      preload: [target: targets]
  end

  @spec _preload_report_groups(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_report_groups(query) do
    from actions in query,
      left_join: report_groups in assoc(actions, :report_groups),
      preload: [report_groups: report_groups]
  end

  @spec _preload_report_group_reports_and_reporters(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_report_group_reports_and_reporters(query) do
    from actions in query,
      left_join: report_groups in assoc(actions, :report_group),
      left_join: reports in assoc(report_groups, :reports),
      left_join: reporters in assoc(reports, :reporter),
      preload: [report_group: {report_groups, reports: {reports, reporter: reporters}}]
  end

  def generate_discord_message_text(nil), do: nil

  def generate_discord_message_text(action) do
    action =
      if Ecto.assoc_loaded?(action.target) do
        action
      else
        Teiserver.Moderation.get_action(action.id,
          preload: [:target]
        )
      end

    if action do
      until =
        if action.expires do
          "**Until:** " <> TimexHelper.date_to_discord_str(action.expires)
        else
          "**Permanent**"
        end

      restriction_list = action.restrictions |> Enum.join(", ")

      restriction_string =
        if Enum.count(action.restrictions) > 1 do
          "**Restrictions:** #{restriction_list}"
        else
          "**Restriction:** #{restriction_list}"
        end

      formatted_reason =
        Regex.replace(~r/https:\/\/discord.gg\/\S+/, action.reason, "--discord-link--")

      [
        "--------------------------------------------",
        "`#{action.target.name}` has been moderated.",
        "**Reason:** #{formatted_reason}",
        restriction_string,
        until
      ]
      |> List.flatten()
      |> Enum.join("\n")
      |> String.replace("\n\n", "\n")
    end
  end

  @spec maybe_create_discord_post(Action.t()) :: any
  def maybe_create_discord_post(action) do
    post_to_discord =
      cond do
        action.hidden -> false
        Enum.member?(action.restrictions, "Bridging") -> false
        Enum.member?(action.restrictions, "Note") -> false
        action.reason == "Banned (Automod)" -> false
        true -> true
      end

    if post_to_discord do
      message = generate_discord_message_text(action)

      posting_result = Communication.new_discord_message("Public moderation log", message)

      case posting_result do
        {:ok, %{id: message_id}} ->
          Moderation.update_action(action, %{discord_message_id: message_id})

        {:error, :discord_disabled} ->
          nil
      end

      posting_result
    else
      nil
    end
  end

  @spec maybe_update_discord_post(Action.t()) :: any
  def maybe_update_discord_post(action) do
    post_to_discord =
      cond do
        action.hidden -> false
        Enum.member?(action.restrictions, "Bridging") -> false
        Enum.member?(action.restrictions, "Note") -> false
        action.reason == "Banned (Automod)" -> false
        true -> true
      end

    cond do
      post_to_discord == false ->
        if action.discord_message_id do
          Communication.delete_discord_message("Public moderation log", action.discord_message_id)
          Moderation.update_action(action, %{discord_message_id: nil})
        end

        nil

      action.discord_message_id == nil ->
        maybe_create_discord_post(action)

      true ->
        message = generate_discord_message_text(action)

        if message do
          Communication.edit_discord_message(
            "Public moderation log",
            action.discord_message_id,
            message
          )
        else
          Communication.delete_discord_message("Public moderation log", action.discord_message_id)
          Moderation.update_action(action, %{discord_message_id: nil})
        end
    end
  end
end
