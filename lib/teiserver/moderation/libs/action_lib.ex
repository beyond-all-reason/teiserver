defmodule Teiserver.Moderation.ActionLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Moderation.Action

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-triangle"

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

  @spec make_favourite(Map.t()) :: Map.t()
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

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
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
    query = if :reports in preloads, do: _preload_reports(query), else: query

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

  @spec _preload_reports(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_reports(query) do
    from actions in query,
      left_join: reports in assoc(actions, :reports),
      preload: [reports: reports]
  end

  @spec _preload_report_group_reports_and_reporters(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_report_group_reports_and_reporters(query) do
    from actions in query,
      left_join: report_groups in assoc(actions, :report_group),
      left_join: reports in assoc(report_groups, :reports),
      left_join: reporters in assoc(reports, :reporter),
      preload: [report_group: {report_groups, reports: {reports, reporter: reporters}}]
  end
end
