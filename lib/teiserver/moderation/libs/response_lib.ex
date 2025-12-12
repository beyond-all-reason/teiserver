defmodule Teiserver.Moderation.ResponseLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Response

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-reply"

  @spec colour :: atom
  def colour, do: :info2

  @spec list_actions() :: [{String.t(), String.t()}]
  def list_actions() do
    [
      {"Ignore", "fa-solid fa-clock"},
      {"Warn", Teiserver.Moderation.ActionLib.action_icon("Warn")},
      {"Mute", Teiserver.Moderation.ActionLib.action_icon("Mute")},
      {"Suspend", Teiserver.Moderation.ActionLib.action_icon("Suspend")},
      {"Ban", Teiserver.Moderation.ActionLib.action_icon("Ban")}
    ]
  end

  # Queries
  @spec query_responses() :: Ecto.Query.t()
  def query_responses do
    from(responses in Response)
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

  def _search(query, :user_id, user_id) do
    from responses in query,
      where: responses.user_id == ^user_id
  end

  def _search(query, :report_id, report_id) do
    from responses in query,
      where: responses.report_id == ^report_id
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from responses in query,
      order_by: [desc: responses.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from responses in query,
      order_by: [asc: responses.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :report in preloads, do: _preload_report(query), else: query
    query
  end

  @spec _preload_report(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_report(query) do
    from responses in query,
      left_join: reports in assoc(responses, :report),
      preload: [report: reports]
  end
end
