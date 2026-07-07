defmodule TeiserverWeb.Battle.MatchLive.SubComponents.BalanceComponent do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.CoreComponents
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 1, rgba_css: 2]
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle.MatchLib

  attr :algorithm_options, :list, required: true
  attr :algorithm, :string, required: true
  attr :match, :map, required: true
  attr :members, :list, required: true
  attr :rating_logs, :map, required: true
  attr :parties, :map, required: true

  def balance_tab(assigns) do
    # Now for balance related stuff
    partied_players =
      assigns.members
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.user_id end)

    groups =
      partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.filter(fn userid -> assigns.rating_logs[userid] != nil end)
          |> Enum.map(fn userid ->
            %{userid => assigns.rating_logs[userid].value}
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Enum.filter(fn userid -> assigns.rating_logs[userid] != nil end)
          |> Map.new(fn userid ->
            {userid, assigns.rating_logs[userid].value}
          end)
      end)
      |> List.flatten()

    past_balance =
      BalanceLib.create_balance(groups, assigns.match.team_count,
        algorithm: assigns.algorithm,
        debug_mode?: true
      )
      |> Map.put(:balance_mode, :grouped)

    # What about new balance?
    new_balance = generate_new_balance_data(assigns.match, assigns.algorithm)

    balanced_members =
      if assigns.rating_logs == %{} do
        # It will go here if the match is unprocessed or if
        # there are no rating logs e.g. unrated match
        []
      else
        assigns.members
        |> Enum.filter(fn x -> assigns.rating_logs[x.user_id] != nil end)
        |> Enum.map(fn x ->
          team_id = get_team_id(x.user_id, past_balance.team_players)
          Map.put(x, :team_id, team_id)
        end)
        |> Enum.sort_by(
          fn m -> assigns.rating_logs[m.user_id].value["old_rating_value"] end,
          &>=/2
        )
        |> Enum.sort_by(fn m -> m.team_id end, &<=/2)
      end

    assigns =
      assigns
      |> assign(:past_balance, past_balance)
      |> assign(:new_balance, new_balance)
      |> assign(:balanced_members, balanced_members)

    ~H"""
    <form method="post" class="">
      <.input
        type="select"
        label="Balance Algorithm"
        options={@algorithm_options}
        name="algorithm"
        value={@algorithm}
        phx-change="update-algorithm"
      />
    </form>
    <br />

    <h4>Based on data at the time</h4>

    <div class="table-responsive">
      <table class="table">
        <tbody>
          <tr>
            <td>Team 1</td>
            <td>
              Rating: {@past_balance.ratings[1] |> round(2)}
            </td>
            <td>
              St Dev: {@past_balance.stdevs[1] |> round(2)}
            </td>
          </tr>
          <tr>
            <td>Team 2</td>
            <td>
              Rating: {@past_balance.ratings[2] |> round(2)}
            </td>
            <td>
              St Dev: {@past_balance.stdevs[2] |> round(2)}
            </td>
          </tr>

          <tr>
            <td>Deviation</td>
            <td colspan="2">{@past_balance.deviation}</td>
          </tr>
          <tr>
            <td>Time Taken (ms)</td>
            <td colspan="2">{@past_balance.time_taken / 1000}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <textarea name="" id="" rows={Enum.count(@past_balance.logs)} class="form-control"><%= @past_balance.logs |> Enum.join("\n") %></textarea>
    <hr />
    <div class="table-responsive">
      <table class="table table-sm">
        <thead>
          <tr>
            <th colspan="2">Name & Party</th>
            <th>Team</th>
            <th colspan="1">Rating</th>
            <th colspan="1">Uncertainty</th>
          </tr>
        </thead>
        <tbody>
          <%= for m <- @balanced_members do %>
            <% rating = @rating_logs[m.user_id]
            {party_colour, party_idx} = Map.get(@parties, m.party_id, {nil, nil}) %>
            <tr>
              <td>
                {m.user.name}
              </td>
              <%= if party_colour do %>
                <td style={"background-color: #{rgba_css(party_colour, 0.3)};"} width="50">
                  <Fontawesome.icon icon={party_idx} style="solid" size="lg" />
                </td>
              <% else %>
                <td width="50">
                  &nbsp;
                </td>
              <% end %>
              <td>{m.team_id + 1}</td>
              <td>
                <%= if rating != nil do %>
                  {(rating.value["rating_value"] - rating.value["rating_value_change"])
                  |> round(2)}
                <% end %>
              </td>
              <td>
                <%= if rating != nil do %>
                  {(rating.value["uncertainty"] - rating.value["uncertainty_change"])
                  |> round(2)}
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    <br />

    <h4>If balance was made using current ratings</h4>
    <div class="table-responsive">
      <table class="table">
        <tbody>
          <tr>
            <td>Team 1</td>
            <td>{@new_balance.ratings[1] |> round(2)}</td>
          </tr>
          <tr>
            <td>Team 2</td>
            <td>{@new_balance.ratings[2] |> round(2)}</td>
          </tr>
          <tr>
            <td>Deviation</td>
            <td>{@new_balance.deviation}</td>
          </tr>
          <tr>
            <td>Time Taken (ms)</td>
            <td>{@new_balance.time_taken / 1000}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <textarea name="" id="" rows={Enum.count(@new_balance.logs)} class="form-control"><%= @new_balance.logs |> Enum.join("\n") %></textarea>
    """
  end

  def get_team_id(player_id, team_players) do
    {team_id, _players} =
      Enum.find(team_players, fn {_k, player_ids} ->
        Enum.any?(player_ids, fn x -> x == player_id end)
      end)

    # team_id should start at 0 even though first key is 1
    team_id - 1
  end

  defp generate_new_balance_data(match, algorithm) do
    # For the section "If balance we made using current ratings", do not fuzz ratings
    # This means the rating used is exactly equal to what is stored in database
    fuzz_multiplier = 0
    rating_type = MatchLib.game_type(match.team_size, match.team_count)

    partied_players =
      match.members
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.user_id end)

    groups =
      partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.map(fn userid ->
            %{userid => BalanceLib.get_user_rating_rank(userid, rating_type, fuzz_multiplier)}
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Map.new(fn userid ->
            {userid, BalanceLib.get_user_rating_rank(userid, rating_type, fuzz_multiplier)}
          end)
      end)
      |> List.flatten()

    BalanceLib.create_balance(groups, match.team_count, algorithm: algorithm, debug_mode?: true)
    |> Map.put(:balance_mode, :grouped)
  end
end
