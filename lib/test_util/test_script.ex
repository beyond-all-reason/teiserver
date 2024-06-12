defmodule TestScript do
  @moduledoc """
  This module is not used anywhere but it can be called while developing to create 4 users for testing:
  Alpha, Bravo, Charlie, Delta
  password is password


  Run the server while enabling iex commands:

  iex -S mix phx.server
  TestScript.run()
  """
  alias Teiserver.Helper.StylingHelper
  require Logger
  alias Teiserver.{Account, CacheUser}
  alias Teiserver.Game.MatchRatingLib

  def run() do
    if Application.get_env(:teiserver, Teiserver)[:enable_hailstorm] do
      # Start by rebuilding the database


      users = [
        %{
          name: "1Chev",
          player_minutes: 0,
          os: 17
        },
        %{
          name: "2Chev",
          player_minutes: 5 * 60,
          os: 17
        },
        %{
          name: "3Chev",
          player_minutes: 15 * 60,
          os: 17
        },
        %{
          name: "4Chev",
          player_minutes: 100 * 60,
          os: 17
        },
        %{
          name: "5Chev",
          player_minutes: 250 * 60,
          os: 17
        },
        %{
          name: "6Chev",
          player_minutes: 1001 * 60,
          os: 17
        },
        %{
          name: "7Chev",
          player_minutes: 1001 * 60,
          os: 17,
          rank_override: 6
        },
        %{
          name: "8Chev",
          player_minutes: 1001 * 60,
          os: 17,
          rank_override: 7
        }
      ]

      user_names = Enum.map(users, fn x -> x.name end)
      make_accounts(user_names)
      update_stats(users)

      "Test script finished successfully"
    else
      Logger.error("Hailstorm mode is not enabled, you cannot run the fakedata task")
    end
  end

  defp make_accounts(list_of_names) do
    root_user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")

    fixed_users =
      list_of_names
      |> Enum.map(fn x -> make_user(x, root_user) end)
      |> Enum.filter(fn x -> x != nil end)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Teiserver.Account.User, fixed_users)
    |> Teiserver.Repo.transaction()
  end

  # root_user is used to copy password and hash
  # returns nil if user exists
  defp make_user(name, root_user, day \\ 0, minutes \\ 0) do
    name = name |> String.replace(" ", "")

    case Teiserver.Account.UserCacheLib.get_user_by_name(name) do
      nil ->
        %{
          name: name,
          email: "#{name}",
          password: root_user.password,
          permissions: ["admin.dev.developer"],
          icon: "fa-solid #{StylingHelper.random_icon()}",
          colour: StylingHelper.random_colour(),
          trust_score: 10_000,
          behaviour_score: 10_000,
          roles: ["Verified"],
          data: %{
            lobby_client: "FakeData",
            bot: false,
            password_hash: root_user.data["password_hash"]
          },
          inserted_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert,
          updated_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert
        }

      # Handle not nil
      _ ->
        Logger.info("#{name} already exists")
        nil
    end
  end

  # This allows us to round off microseconds and convert datetime to naive_datetime
  defp time_convert(t) do
    t
    |> Timex.to_unix()
    |> Timex.from_unix()
    |> Timex.to_naive_datetime()
  end

  defp update_stats(users) when is_list(users) do
    for user <- users, do: update_stats(user.name, user.player_minutes, user.os, user[:rank_override])
  end

  # Update the database with player minutes
  def update_stats(username, player_minutes, os, rank_override \\ nil) do
    user = Teiserver.Account.UserCacheLib.get_user_by_name(username)
    user_id = user.id

    user_stat = %{
      player_minutes: player_minutes,
      total_minutes: player_minutes
    }

    user_stat = cond do
      rank_override != nil -> Map.put(user_stat, :rank_override, rank_override)
      true -> user_stat
    end

    Account.update_user_stat(user_id, user_stat)

    # Now recalculate ranks
    # This calc would usually be done in do_login
    rank = CacheUser.calculate_rank(user_id)

    user = %{
      user
      | rank: rank
    }

    CacheUser.update_user(user, true)
    update_rating(user.id, os)
  end

  defp update_rating(user_id, os) do
    new_uncertainty = 6
    new_skill = os + new_uncertainty
    new_rating_value = os
    new_leaderboard_rating = os - 2 * new_uncertainty
    rating_type = "Team"
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]

    case Account.get_rating(user_id, rating_type_id) do
      nil ->
        Account.create_rating(%{
          user_id: user_id,
          rating_type_id: rating_type_id,
          rating_value: new_rating_value,
          skill: new_skill,
          uncertainty: new_uncertainty,
          leaderboard_rating: new_leaderboard_rating,
          last_updated: Timex.now()
        })

      existing ->
        Account.update_rating(existing, %{
          rating_value: new_rating_value,
          skill: new_skill,
          uncertainty: new_uncertainty,
          leaderboard_rating: new_leaderboard_rating,
          last_updated: Timex.now()
        })
    end
  end
end
