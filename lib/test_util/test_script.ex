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
      accounts = [
        %{
          name: "Alpha",
          minutes: 360,
          os: 15
        },
        %{
          name: "Bravo",
          minutes: 360,
          os: 20
        },
        %{
          name: "Charlie",
          minutes: 0,
          os: 17
        },
        %{
          name: "Delta",
          minutes: 0,
          os: 17
        },
        %{
          name: "spadsbot",
          is_bot?: true
        }
      ]

      # Accounts
      make_accounts(accounts)

      Enum.map(accounts, fn x ->
        update_stats(x.name, x[:minutes], x[:os])
      end)

      "Test script finished successfully"
    else
      Logger.error("Hailstorm mode is not enabled, you cannot run the fakedata task")
    end
  end

  # root_user is used to copy password and hash
  # returns nil if user exists
  defp make_user(name, root_user, opts) do
    default_opts = [is_bot?: false]
    opts = Keyword.merge(default_opts, opts)
    is_bot? = opts[:is_bot?]
    day = 0
    minutes = 0
    # You still have to set the bot role on website because if you set it here it will get reset after they accept the T&C
    roles = ["Verified"]


    case Teiserver.Account.UserCacheLib.get_user_by_name(name) do
      nil ->
        %{
          name: name |> String.replace(" ", ""),
          email: UUID.uuid1(),
          password: root_user.password,
          permissions: ["admin.dev.developer"],
          icon: "fa-solid #{StylingHelper.random_icon()}",
          colour: StylingHelper.random_colour(),
          trust_score: 10_000,
          behaviour_score: 10_000,
          roles: roles,
          data: %{
            lobby_client: "FakeData",
            bot: is_bot?,
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

  defp make_accounts(accounts) do
    root_user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")

    fixed_users =
      accounts
      |> Enum.map(fn x -> make_user(x.name, root_user, [is_bot?: x[:is_bot?]]) end)
      |> Enum.filter(fn x -> x != nil end)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Teiserver.Account.User, fixed_users)
    |> Teiserver.Repo.transaction()
  end

  # This allows us to round off microseconds and convert datetime to naive_datetime
  defp time_convert(t) do
    t
    |> Timex.to_unix()
    |> Timex.from_unix()
    |> Timex.to_naive_datetime()
  end

  def update_stats(_username, player_minutes, os) when player_minutes == nil or os == nil do
    #do nothing
  end

  # Update the database with player minutes
  def update_stats(username, player_minutes, os) do
    user = Teiserver.Account.UserCacheLib.get_user_by_name(username)
    user_id = user.id

    Account.update_user_stat(user_id, %{
      player_minutes: player_minutes,
      total_minutes: player_minutes
    })

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
