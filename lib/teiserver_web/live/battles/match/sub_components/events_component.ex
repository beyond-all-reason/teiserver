defmodule TeiserverWeb.Battle.MatchLive.SubComponents.EventsComponent do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.CoreComponents

  alias Teiserver.Telemetry
  attr :match_id, :integer, required: true
  attr :members, :list, required: true
  attr :events_by_type, :list, required: true

  def events_tab(assigns) do
    raw_events =
      Telemetry.list_simple_match_events(
        where: [match_id: assigns.match_id],
        preload: [:event_types]
      )

    team_lookup =
      assigns.members
      |> Map.new(fn m ->
        {m.user_id, m.team_id}
      end)

    events_by_team_and_type =
      raw_events
      |> Enum.group_by(
        fn e ->
          {team_lookup[e.user_id] || -1, e.event_type.name}
        end,
        fn _event ->
          1
        end
      )
      |> Enum.map(fn {key, vs} ->
        {key, Enum.count(vs)}
      end)
      |> Enum.sort_by(fn v -> v end, &<=/2)

    assigns =
      assigns
      |> assign(:events_by_team_and_type, events_by_team_and_type)

    ~H"""
    <div class="row">
      <div class="col">
        <h4>By type</h4>
        <.table id="by_type" rows={@events_by_type} table_class="table-sm">
          <:col :let={{name, _}} label="Event">{name}</:col>
          <:col :let={{_, count}} label="Count">{count}</:col>
        </.table>
      </div>

      <div class="col">
        <h4>By team and type</h4>
        <.table id="by_type" rows={@events_by_team_and_type} table_class="table-sm">
          <:col :let={{{team, _}, _}} label="Team">{team + 1}</:col>
          <:col :let={{{_, name}, _}} label="Event">{name}</:col>
          <:col :let={{_, count}} label="Count">{count}</:col>
        </.table>
      </div>
    </div>
    """
  end
end
