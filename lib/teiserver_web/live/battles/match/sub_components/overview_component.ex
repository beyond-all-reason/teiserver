defmodule TeiserverWeb.Battle.MatchLive.SubComponents.OverviewComponent do
  @moduledoc false
  use TeiserverWeb, :component
  import Teiserver.Helper.DateHelper, only: [date_to_str: 2, duration_to_str_short: 1]

  attr :match, :map, required: true
  attr :tz, :string, required: true
  attr :current_user, :map, required: true

  def overview_tab(assigns) do
    ~H"""
    <div class="row">
      <div class="col">
        <strong>Team count:</strong> {@match.team_count}
      </div>

      <div class="col">
        <strong>Team size:</strong> {@match.team_size}
      </div>

      <div class="col">
        <strong>Started:</strong> {date_to_str(@match.started, format: :ymd_hms, tz: @tz)}
      </div>

      <div class="col">
        <strong>Finished:</strong> {date_to_str(@match.finished, format: :ymd_hms, tz: @tz)}
      </div>

      <%= if allow?(@current_user, "admin.dev") do %>
        <div class="col">
          <strong>Tag count:</strong> {Map.keys(@match.tags) |> Enum.count()}
        </div>
      <% end %>
    </div>

    <div class="row mt-2">
      <div class="col">
        <strong>Host:</strong> {@match.founder.name}
      </div>

      <div class="col">
        <strong>Duration:</strong> {duration_to_str_short(@match.game_duration)}
      </div>

      <div class="col">
        <strong>Bot count:</strong> {Enum.count(@match.bots)}
      </div>
    </div>
    <hr />

    <%= if allow?(@current_user, "Moderator") do %>
      Match data <textarea class="form-control" style="font-family: monospace" rows="20"><%= Jason.encode!(@match.data, pretty: true) %></textarea> Match bots <textarea
        class="form-control"
        style="font-family: monospace"
        rows="20"
      ><%= Jason.encode!(@match.bots, pretty: true) %></textarea>
    <% end %>
    """
  end
end
