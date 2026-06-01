defmodule TeiserverWeb.Battle.MatchLive.SubComponents.PlayersComponent do
  @moduledoc false
  use TeiserverWeb, :component
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 1, rgba_css: 2]
  import Teiserver.Helper.NumberHelper, only: [normalize: 1, round: 2]

  alias Teiserver.Account.RatingLib
  alias Teiserver.Helper.NumberHelper
  alias Teiserver.Battle.MatchLib

  attr :members, :list, required: true
  attr :match, :map, required: true
  attr :rating_logs, :map, required: true
  attr :parties, :map, required: true
  attr :current_user, :map, required: true

  def players_tab(assigns) do
    find_current_user =
      Enum.find(assigns.members, fn x ->
        x.user_id == assigns.current_user.id
      end)

    current_user_team_id = if find_current_user, do: find_current_user.team_id, else: nil
    prediction_text = get_prediction_text(assigns.rating_logs, assigns.members)

    assigns =
      assigns
      |> assign(:current_user_team_id, current_user_team_id)
      |> assign(:prediction_text, prediction_text)

    ~H"""
    <div class="table-responsive">
      <table class="table table-sm">
        <thead>
          <tr>
            <th colspan="3">Name & Party</th>
            <th>Team</th>

            <th>Rating</th>
            <th>Uncertainty</th>
            <th>Num Matches</th>
            <th>Play</th>

            <th colspan="1">&nbsp;</th>
          </tr>
        </thead>
        <tbody>
          <%= for m <- @members do %>
            <% rating = @rating_logs[m.user_id]
            {party_colour, party_idx} = Map.get(@parties, m.party_id, {nil, nil})

            play_percentage =
              if m.exit_status != :stayed do
                (m.left_after / @match.game_duration * 100) |> round()
              end %>
            <tr>
              <td
                style={"vertical-align: middle; background-color: #{m.user.colour}; color: #FFF;"}
                width="22"
              >
                <%= if m.team_id == @match.winning_team do %>
                  <i class="fa-fw fa-solid fa-trophy "></i>
                <% end %>
              </td>

              <td style={"background-color: #{rgba_css m.user.colour};"}>
                {m.user.name}
              </td>

              <%= if party_colour do %>
                <td style={"background-color: #{rgba_css(party_colour, 0.3)};"} width="50">
                  <Fontawesome.icon icon={party_idx} style="solid" size="lg" />
                </td>
              <% else %>
                <td style={"background-color: #{rgba_css m.user.colour};"} width="50">
                  &nbsp;
                </td>
              <% end %>

              <td>{m.team_id + 1}</td>

              <td>
                <%= if rating != nil do %>
                  {rating.value["old_rating_value"]
                  |> round(2)}
                <% end %>
              </td>

              <td>
                <%= if rating != nil do %>
                  {rating.value["old_uncertainty"]
                  |> round(2)}
                <% end %>
              </td>

              <td>
                <%= if rating != nil do %>
                  {normalize(rating.value["old_num_matches"])}
                <% end %>
              </td>

              <td>
                <%= case m.exit_status do %>
                  <% :stayed -> %>
                  <% :early -> %>
                    <i class="fa-fw fa-solid fa-clock text-warning"></i> &nbsp; {play_percentage}%
                  <% :abandoned -> %>
                    <i class="fa-fw fa-solid fa-person-running text-danger"></i>
                    &nbsp; {play_percentage}%
                  <% :noshow -> %>
                    <i class="fa-fw fa-solid fa-user-ninja text-info2"></i>
                <% end %>
              </td>

              <td>
                <div :if={m.user_id != @current_user.id} style="display: flex;">
                  <div style="flex: 1">
                    <a
                      href={~p"/moderation/report_user/#{m.user_id}"}
                      class="btn btn-sm btn-warning "
                    >
                      <i class={"fa-fw #{Teiserver.Moderation.ReportLib.icon()}"}></i>&nbsp;
                      Report
                    </a>
                  </div>

                  <div style="flex: 1">
                    <a
                      phx-click="give-accolade"
                      phx-value-recipient_name={m.user.name}
                      phx-value-recipient_id={m.user.id}
                      phx-value-current_user_team_id={@current_user_team_id}
                      phx-value-recipient_team_id={m.team_id}
                      class={[
                        "btn btn-sm btn-success"
                      ]}
                    >
                      <i class="fa-solid fa-award"></i>&nbsp;
                      Accolade
                    </a>
                  </div>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    <table>
      <tbody>
        <%= for m <-  @prediction_text do %>
          <tr>
            <td style="padding-right:10px;">{m.label}</td>
            <td>{m.value}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp get_prediction_text(rating_logs, members) do
    if rating_logs == %{} do
      # Unrated match will not have rating logs
      []
    else
      simple_rating_logs =
        members
        |> Enum.filter(fn m -> rating_logs[m.user_id] != nil end)
        |> Enum.map(fn m ->
          logs = rating_logs[m.user_id].value

          %{
            team_id: m.team_id,
            old_skill: logs["old_skill"],
            old_uncertainty: logs["old_uncertainty"]
          }
        end)
        |> Enum.group_by(fn x -> x.team_id end)
        |> Enum.map(fn {_key, value} ->
          Enum.map(value, fn y ->
            {y.old_skill, y.old_uncertainty}
          end)
        end)

      # predict_win may not be reliable if team count not equal to 2
      if length(simple_rating_logs) == 2 do
        prediction = Openskill.predict_win(simple_rating_logs)

        prediction_text_values =
          Enum.map(prediction, fn x ->
            percentage = (x * 100) |> NumberHelper.round(1)
            "#{percentage}%"
          end)

        team_ratings =
          Openskill.Util.team_rating(simple_rating_logs)

        skill_text_values =
          Enum.map(team_ratings, fn {skill, _sigma_sq, _extra1, _extra2} ->
            "#{skill |> NumberHelper.round(1)}"
          end)

        uncertainty_text_values =
          Enum.map(team_ratings, fn {_skill, sigma_sq, _extra1, _extra2} ->
            "#{sigma_sq |> NumberHelper.round(1)}"
          end)

        [
          %{
            label: "Openskill library win predict: ",
            value: "[#{prediction_text_values |> Enum.join(", ")}]"
          },
          %{
            label: "Team skill (μ): ",
            value: "[#{skill_text_values |> Enum.join(", ")}]"
          },
          %{
            label: "Team uncertainty squared (σ²): ",
            value: "[#{uncertainty_text_values |> Enum.join(", ")}]"
          }
        ]
      else
        []
      end
    end
  end
end
