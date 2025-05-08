defmodule Mix.Tasks.Teiserver.Fakedata do
  @moduledoc """
  Run with mix teiserver.fakedata
  """

  use Mix.Task

  alias Teiserver.{Account, Logging, Battle, Moderation}
  alias Teiserver.Helper.StylingHelper
  alias Teiserver.Battle.MatchLib
  require Logger

  @settings %{
    # days: 365,
    days: 5,
    memory: 1024 * 1024 * 1024,
    maps: ["Koom valley", "Comet catcher", "Tabula"]
  }

  defp matches_per_day, do: :rand.uniform(5) + 2
  defp users_per_day, do: :rand.uniform(5) + 2

  @spec run(list()) :: :ok
  def run(_args) do
    # Start by rebuilding the database
    Mix.Task.run("ecto.reset")

    # Accounts
    make_accounts()

    make_matches()
    make_telemetry()
    make_moderation()
    make_one_time_code()

    # Add fake playtime data to all our non-bot users
    Mix.Task.run("teiserver.fake_playtime")

    :timer.sleep(50)

    IO.puts(
      "\nFake data insertion complete. You can now login with the email 'root@localhost' and password 'password'\nA one-time link has been created: http://localhost:4000/one_time_login/fakedata_code\n"
    )
  end

  defp add_root_user() do
    {:ok, user} =
      Account.create_user(%{
        name: "root",
        email: "root@localhost",
        password: Account.spring_md5_password("password"),
        roles: ["Server", "Verified"],
        permissions: ["admin.dev.developer", "Server"],
        icon: "fa-solid fa-power-off",
        colour: "#00AA00",
        data: %{
          lobby_client: "FakeData"
        }
      })

    user
  end

  @doc """
  Uses :application_metadata_cache store to generate a random username
  based on the keys random_names_1, random_names_2 and random_names_3
  if you override these keys with an empty list you can generate shorter names
  """
  @spec generate_throwaway_name() :: String.t()
  def generate_throwaway_name do
    [
      Teiserver.store_get(:application_metadata_cache, "random_names_1"),
      Teiserver.store_get(:application_metadata_cache, "random_names_2"),
      Teiserver.store_get(:application_metadata_cache, "random_names_3")
    ]
    |> Enum.filter(fn l -> l != [] end)
    |> Enum.map_join(" ", fn l -> Enum.random(l) |> String.capitalize() end)
  end

  defp make_accounts() do
    root_user = add_root_user()

    new_users =
      Range.new(0, @settings.days)
      |> ParallelStream.map(fn day ->
        Range.new(0, users_per_day())
        |> ParallelStream.map(fn _ ->
          minutes = :rand.uniform(24 * 60)

          %{
            name: generate_throwaway_name() |> String.replace(" ", ""),
            email: UUID.uuid1(),
            password: root_user.password,
            permissions: [],
            icon: "fa-solid #{StylingHelper.random_icon()}",
            colour: StylingHelper.random_colour(),
            roles: ["Verified"],
            data: %{
              lobby_client: "FakeData",
              bot: false,
              roles: ["Verified"]
            },
            inserted_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert,
            updated_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert
          }
        end)
        |> Enum.to_list()
      end)
      |> Enum.to_list()
      |> List.flatten()

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Teiserver.Account.User, new_users)
    |> Teiserver.Repo.transaction()
  end

  defp make_telemetry() do
    # First we need to make by the minute telemetry data
    Range.new(0, @settings.days)
    |> Enum.each(fn day ->
      date = Timex.today() |> Timex.shift(days: -day)

      user_ids =
        Account.list_users(
          search: [
            inserted_after: Timex.to_datetime(date),
            not_has_role: "Bot"
          ],
          select: [:id]
        )
        |> Enum.map(fn %{id: id} -> id end)

      user_count = Enum.count(user_ids)

      lobby_count =
        user_count
        |> Kernel.div(6)
        |> round
        |> max(1)

      logs =
        Range.new(1, 1440)
        |> Enum.map(fn m ->
          {menu, lobby, player, spectator} = {
            random_pick_from(user_ids, 0.2),
            random_pick_from(user_ids, 0.2),
            random_pick_from(user_ids, 0.2),
            random_pick_from(user_ids, 0.2)
          }

          total = [menu, lobby, player, spectator] |> List.flatten()

          timestamp =
            date
            |> Timex.to_datetime()
            |> Timex.shift(minutes: m)
            |> Timex.to_unix()
            |> Timex.from_unix()

          %{
            timestamp: timestamp,
            data: %{
              battle: %{
                lobby: :rand.uniform(lobby_count),
                total: :rand.uniform(lobby_count) * 4,
                started: :rand.uniform(lobby_count),
                stopped: :rand.uniform(lobby_count),
                in_progress: :rand.uniform(lobby_count)
              },
              client: %{
                menu: random_pick_from(user_ids),
                lobby: random_pick_from(user_ids),
                player: random_pick_from(user_ids),
                spectator: random_pick_from(user_ids),
                total: total
              },
              os_mon: %{
                cpu_avg1: :rand.uniform(50) + 50,
                cpu_avg5: :rand.uniform(50) + 50,
                cpu_avg15: :rand.uniform(50) + 50,
                cpu_nprocs: :rand.uniform(50) + 50,
                system_mem: %{
                  free_swap: :rand.uniform(10) * @settings.memory,
                  total_swap: :rand.uniform(10) * @settings.memory,
                  free_memory: :rand.uniform(10) * @settings.memory,
                  total_memory: :rand.uniform(10) * @settings.memory,
                  cached_memory: :rand.uniform(10) * @settings.memory,
                  buffered_memory: :rand.uniform(10) * @settings.memory,
                  available_memory: :rand.uniform(10) * @settings.memory,
                  system_total_memory: 4 * @settings.memory
                }
              },
              server: %{
                bots_connected: :rand.uniform(lobby_count),
                users_connected: :rand.uniform(lobby_count) * 2,
                bots_disconnected: :rand.uniform(lobby_count),
                users_disconnected: :rand.uniform(lobby_count) * 2
              },
              matchmaking: %{}
            }
          }
        end)

      Ecto.Multi.new()
      |> Ecto.Multi.insert_all(:insert_all, Teiserver.Logging.ServerMinuteLog, logs)
      |> Teiserver.Repo.transaction()
    end)

    # Now persist day values
    Range.new(0, @settings.days)
    |> Enum.each(fn _day ->
      Logging.Tasks.PersistServerDayTask.perform(%{})
      Logging.Tasks.PersistMatchDayTask.perform(%{})
    end)

    # And monthly
    months = (@settings.days / 31) |> :math.ceil() |> round

    Range.new(0, months)
    |> Enum.each(fn _day ->
      Logging.Tasks.PersistServerMonthTask.perform(%{})
      Logging.Tasks.PersistMatchMonthTask.perform(%{})
    end)
  end

  defp make_moderation() do
    Range.new(0, @settings.days)
    |> Enum.each(fn day ->
      date = Timex.today() |> Timex.shift(days: -day)

      users =
        Account.list_users(
          search: [
            inserted_after: Timex.to_datetime(date),
            not_has_role: "Bot"
          ],
          select: [:id, :name]
        )
        |> Enum.map(fn %{id: id, name: name} -> {id, name} end)

      report_count = (Enum.count(users) / 7) |> round()

      basic_reports =
        Range.new(0, report_count)
        |> Enum.map(fn _ ->
          if Enum.count(users) > 1 do
            [{reporter_id, _}, {target_id, _} | _] = Enum.shuffle(users) |> Enum.take(2)

            report_time =
              date
              |> Timex.to_datetime()
              |> Timex.shift(minutes: 10 + :rand.uniform(1000))
              |> time_convert

            %{
              reporter_id: reporter_id,
              target_id: target_id,
              type: "Chat",
              sub_type: Enum.random(~w(any spam bullying abusive)),
              inserted_at: report_time,
              updated_at: report_time
            }
          end
        end)
        |> Enum.reject(&(&1 == nil))

      match_reports =
        Battle.list_matches(
          search: [
            started_after: date |> Timex.to_datetime(),
            started_before: date |> Timex.to_datetime() |> Timex.shift(days: 1)
          ],
          preload: [:members]
        )
        |> Enum.shuffle()
        |> Enum.take(report_count)
        |> Enum.map(fn match ->
          [reporter, target | _] = Enum.shuffle(match.members) |> Enum.take(2)
          report_time = match.started |> Timex.shift(minutes: 20) |> time_convert

          relationship =
            cond do
              reporter.team_id == target.team_id -> "Ally"
              reporter.team_id != target.team_id -> "Opponent"
            end

          %{
            reporter_id: reporter.user_id,
            target_id: target.user_id,
            type: "Game",
            sub_type: Enum.random(~w(any noob griefing cheating)),
            relationship: relationship,
            match_id: match.id,
            inserted_at: report_time,
            updated_at: report_time
          }
        end)

      Ecto.Multi.new()
      |> Ecto.Multi.insert_all(:insert_all, Moderation.Report, basic_reports ++ match_reports)
      |> Teiserver.Repo.transaction()
    end)
  end

  defp make_matches() do
    Range.new(0, @settings.days)
    |> Enum.each(fn day ->
      date = Timex.today() |> Timex.shift(days: -day)

      users =
        Account.list_users(
          search: [
            inserted_after: Timex.to_datetime(date),
            not_has_role: "Bot"
          ],
          select: [:id, :name]
        )
        |> Enum.map(fn %{id: id, name: name} -> {id, name} end)

      server_uuid = UUID.uuid1()

      Range.new(0, matches_per_day())
      |> Enum.each(fn _ ->
        max_size = Enum.count(users) |> Kernel.div(2) |> :math.floor() |> round
        team_size = min(:rand.uniform(8), max_size)
        shuffled_users = Enum.shuffle(users)
        team1 = shuffled_users |> Enum.take(team_size)
        team2 = shuffled_users |> Enum.reverse() |> Enum.take(team_size)
        team_count = 2
        num_players = team_size * team_count
        game_type = MatchLib.game_type(team_size, team_count)

        team1_score =
          team1
          |> Enum.map(fn {_, name} -> String.length(name) end)
          |> Enum.sum()

        team2_score =
          team2
          |> Enum.map(fn {_, name} -> String.length(name) end)
          |> Enum.sum()

        start_time = Timex.shift(date |> Timex.to_datetime(), minutes: 10 + :rand.uniform(1000))
        end_time = Timex.shift(start_time, minutes: 10 + :rand.uniform(120))

        {:ok, match} =
          Battle.create_match(%{
            server_uuid: server_uuid,
            uuid: UUID.uuid1(),
            map: Enum.random(@settings.maps),
            data: %{},
            tags: %{},
            winning_team: if(team1_score > team2_score, do: 0, else: 1),
            team_count: team_count,
            team_size: team_size,
            passworded: false,
            processed: true,
            game_type: game_type,

            # All rooms are hosted by the same user for now
            founder_id: 1,
            bots: %{},
            queue_id: nil,
            started: start_time,
            finished: end_time
          })

        memberships1 =
          team1
          |> Enum.map(fn {userid, _} ->
            %{
              team_id: 0,
              win: match.winning_team == 0,
              stats: %{
                "damageDealt" => :rand.uniform(1000) * 10,
                "damageReceived" => :rand.uniform(1000) * 10,
                "metalProduced" => :rand.uniform(1000) * 100,
                "metalUsed" => :rand.uniform(1000) * 100,
                "energyProduced" => :rand.uniform(1000) * 1000,
                "energyUsed" => :rand.uniform(1000) * 1000
              },
              party_id: get_party_id(num_players),
              user_id: userid,
              match_id: match.id
            }
          end)

        memberships2 =
          team2
          |> Enum.map(fn {userid, _} ->
            %{
              team_id: 1,
              win: match.winning_team == 1,
              stats: %{
                "damageDealt" => :rand.uniform(1000) * 10,
                "damageReceived" => :rand.uniform(1000) * 10,
                "metalProduced" => :rand.uniform(1000) * 100,
                "metalUsed" => :rand.uniform(1000) * 100,
                "energyProduced" => :rand.uniform(1000) * 1000,
                "energyUsed" => :rand.uniform(1000) * 1000
              },
              party_id: get_party_id(num_players),
              user_id: userid,
              match_id: match.id
            }
          end)

        Ecto.Multi.new()
        |> Ecto.Multi.insert_all(
          :insert_all,
          Battle.MatchMembership,
          memberships1 ++ memberships2
        )
        |> Teiserver.Repo.transaction()
      end)
    end)

    Teiserver.Game.MatchRatingLib.reset_and_re_rate("all")
  end

  defp make_one_time_code() do
    root_user = Account.get_user_by_email("root@localhost")

    Teiserver.Config.update_site_config("user.Enable one time links", "true")

    {:ok, _code} =
      Account.create_code(%{
        value: "fakedata_code$127.0.0.1",
        purpose: "one_time_login",
        expires: Timex.now() |> Timex.shift(hours: 24),
        user_id: root_user.id
      })
  end

  # This allows us to round off microseconds and convert datetime to naive_datetime
  defp time_convert(t) do
    t
    |> Timex.to_unix()
    |> Timex.from_unix()
    |> Timex.to_naive_datetime()
  end

  defp random_pick_from(list, chance \\ 0.5) do
    list
    |> Enum.filter(fn _ ->
      :rand.uniform() < chance
    end)
  end

  # Adds a party id or nil
  defp get_party_id(num_players) do
    case is_in_party?() do
      true ->
        num_parties = trunc(num_players / 4)
        # party id is a string
        "#{Enum.random(1..num_parties)}"

      false ->
        nil
    end
  end

  defp is_in_party? do
    chance_in_party = 40
    # Number from 0 to 100
    random = Enum.random(0..100)
    random <= chance_in_party
  end
end
