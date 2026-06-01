defmodule TeiserverWeb.Battle.MatchLive.SubComponents.RatingsComponent do
  @moduledoc false
  use TeiserverWeb, :component
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 1, rgba_css: 2]
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  attr :members, :list, required: true
  attr :rating_logs, :map, required: true
  attr :parties, :map, required: true
  attr :match, :map, required: true

  def ratings_tab(assigns) do
    ~H"""
    <div class="table-responsive">
      <table class="table table-sm">
        <thead>
          <tr>
            <th colspan="4">Name & Party</th>

            <th>Team</th>

            <th>Pre-game rating</th>

            <th>Post-game rating</th>

            <th>Change</th>
          </tr>
        </thead>

        <tbody>
          <%= for m <- @members do %>
            <% rating = @rating_logs[m.user_id]
            {party_colour, party_idx} = Map.get(@parties, m.party_id, {nil, nil})

            {text_class, icon} =
              if rating do
                cond do
                  rating.value["rating_value_change"] > 0 -> {"text-success", "up"}
                  rating.value["rating_value_change"] < 0 -> {"text-danger", "down"}
                  true -> {"text-warning", "pause"}
                end
              else
                {"text-warning", "pause"}
              end %>
            <tr>
              <td style={"background-color: #{m.user.colour}; color: #FFF;"} width="22">
                <%= if m.team_id == @match.winning_team do %>
                  <i class="fa-fw fa-solid fa-trophy"></i>
                <% end %>
              </td>

              <td style={"background-color: #{m.user.colour}; color: #FFF;"} width="22">
                <Fontawesome.icon icon={m.user.icon} style="" />
              </td>

              <td style={"background-color: #{rgba_css m.user.colour};"}>{m.user.name}</td>

              <%= if party_colour do %>
                <td style={"background-color: #{rgba_css(party_colour, 0.3)};"} width="50">
                  <Fontawesome.icon icon={party_idx} style="solid" size="lg" />
                </td>
              <% else %>
                <td style={"background-color: #{rgba_css m.user.colour};"} width="50">&nbsp;</td>
              <% end %>

              <td>{m.team_id + 1}</td>

              <td>
                <%= if rating do %>
                  {(rating.value["rating_value"] - rating.value["rating_value_change"])
                  |> round(2)}
                <% end %>
              </td>

              <td>
                <%= if rating do %>
                  {rating.value["rating_value"] |> round(2)}
                <% end %>
              </td>

              <td class={text_class}>
                <%= if rating do %>
                  <Fontawesome.icon icon={icon} style="solid" /> {rating.value["rating_value_change"]
                  |> round(2)}
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
