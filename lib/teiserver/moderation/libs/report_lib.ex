defmodule Teiserver.Moderation.ReportLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Report

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-flag"

  @spec colour :: atom
  def colour, do: :warning

  def get_outstanding_report_max_days, do: 31

  @spec make_favourite(map()) :: map()
  def make_favourite(report) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: report.id,
      item_type: "teiserver_moderation_report",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{report.reporter.name} -> #{report.target.name}",
      url: "/teiserver/moderation/reports/#{report.id}"
    }
  end

  def types() do
    [
      {"Chat / Communication", "chat", Teiserver.Chat.LobbyMessageLib.icon()},
      {"In game actions", "actions", Teiserver.Battle.MatchLib.icon()}
    ]
  end

  def sub_types() do
    %{
      "chat" => [
        {"Spam", "spam", "fa-envelopes-bulk"},
        {"Bullying", "bullying", "fa-person-harassing"},
        {"Hate speech", "hate", "fa-triangle-exclamation"},
        {"Other", "other", "fa-face-unamused"}
      ],
      "actions" => [
        {"Noob", "noob", "fa-chevrons-up"},
        {"Griefing", "griefing", "fa-face-angry-horns"},
        {"Cheating", "cheating", "fa-cards"},
        {"Other", "other", "fa-face-unamused"}
      ]
    }
  end

  def sections() do
    [
      {"Chat / Communication", "chat", Teiserver.Chat.LobbyMessageLib.icon()},
      {"In game actions", "actions", Teiserver.Battle.MatchLib.icon()}
    ]
  end

  def sub_sections() do
    %{
      "chat" => [
        {"Spam", "spam", "fa-envelopes-bulk"},
        {"Bullying", "bullying", "fa-person-harassing"},
        {"Hate speech", "hate", "fa-triangle-exclamation"},
        {"Other", "other", "fa-face-unamused"}
      ],
      "actions" => [
        {"Noob", "noob", "fa-chevrons-up"},
        {"Griefing", "griefing", "fa-face-angry-horns"},
        {"Cheating", "cheating", "fa-cards"},
        {"Other", "other", "fa-face-unamused"}
      ]
    }
  end

  # Queries
  @spec query_reports() :: Ecto.Query.t()
  def query_reports do
    from(reports in Report)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
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
    from reports in query,
      where: reports.id == ^id
  end

  def _search(query, :id_in, id_list) do
    from reports in query,
      where: reports.id in ^id_list
  end

  def _search(query, :closed, value) do
    from reports in query,
      where: reports.closed == ^value
  end

  def _search(query, :outstanding, true) do
    from reports in query,
      where: reports.closed == false,
      where: is_nil(reports.result_id)
  end

  def _search(query, :outstanding, false) do
    from reports in query,
      where: reports.closed == true or not is_nil(reports.result_id)
  end

  def _search(query, :target_id, target_id) do
    from reports in query,
      where: reports.target_id == ^target_id
  end

  def _search(query, :target_id_in, id_list) do
    from reports in query,
      where: reports.target_id in ^id_list
  end

  def _search(query, :result_id, result_id) do
    from reports in query,
      where: reports.result_id == ^result_id
  end

  def _search(query, :result_id_in, id_list) do
    from reports in query,
      where: reports.result_id in ^id_list
  end

  def _search(query, :reporter_id, reporter_id) do
    from reports in query,
      where: reports.reporter_id == ^reporter_id
  end

  def _search(query, :reporter_id_in, id_list) do
    from reports in query,
      where: reports.reporter_id in ^id_list
  end

  def _search(query, :no_result, true) do
    from reports in query,
      where: is_nil(reports.result_id)
  end

  def _search(query, :no_result, false) do
    from reports in query,
      where: not is_nil(reports.result_id)
  end

  def _search(query, :inserted_after, datetime) do
    from reports in query,
      where: reports.inserted_at > ^datetime
  end

  def _search(query, :inserted_before, datetime) do
    from reports in query,
      where: reports.inserted_at < ^datetime
  end

  def _search(query, :id_list, id_list) do
    from reports in query,
      where: reports.id in ^id_list
  end

  def _search(query, :state, "Any"), do: query

  def _search(query, :state, "open") do
    from reports in query,
      where: is_nil(reports.result_id) and not reports.closed
  end

  def _search(query, :state, "resolved") do
    from reports in query,
      where: reports.closed or not is_nil(reports.result_id)
  end

  def _search(query, :type, "chat") do
    from reports in query,
      where: reports.type == "chat"
  end

  def _search(query, :type, "actions") do
    from reports in query,
      where: reports.type == "actions"
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from reports in query,
      order_by: [desc: reports.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from reports in query,
      order_by: [asc: reports.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  @spec _preload(Ecto.Query.t(), atom) :: Ecto.Query.t()
  def _preload(query, :reporter) do
    from reports in query,
      left_join: reporters in assoc(reports, :reporter),
      preload: [reporter: reporters]
  end

  def _preload(query, :target) do
    from reports in query,
      left_join: targets in assoc(reports, :target),
      preload: [target: targets]
  end

  def _preload(query, :action) do
    from reports in query,
      left_join: actions in assoc(reports, :action),
      preload: [action: actions]
  end

  def _preload(query, :match) do
    from reports in query,
      left_join: matches in assoc(reports, :match),
      preload: [match: matches]
  end

  def _preload(query, :responses) do
    from reports in query,
      left_join: responses in assoc(reports, :responses),
      preload: [responses: responses]
  end

  def _preload(query, {:user_response, userid}) do
    from reports in query,
      left_join: responses in assoc(reports, :responses),
      on: responses.user_id == ^userid,
      preload: [responses: responses]
  end
end
