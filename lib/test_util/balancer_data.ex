defmodule Teiserver.TestUtil.BalancerData do
@moduledoc """
This module is not used anywhere but it can be called while developing to create 4 users for testing:
Alpha, Bravo, Charlie, Delta
password is password


Run the server while enabling iex commands:

iex -S mix phx.server
Teiserver.TestUtil.BalancerData.run()
"""
  alias Teiserver.TestUtil.BalancerUtil
  alias Teiserver.Helper.StylingHelper
  require Logger



   def run() do
    if Application.get_env(:teiserver, Teiserver)[:enable_hailstorm] do
      # Start by rebuilding the database

      # Accounts
      make_accounts()

      #Adjust ratings
      name = "Alpha"
      minutes=360
      os=15
      BalancerUtil.update_stats(name, minutes,os)
      name = "Bravo"
      minutes=360
      os=20
      BalancerUtil.update_stats(name, minutes,os)
      name = "Charlie"
      minutes=0
      os=17
      BalancerUtil.update_stats(name, minutes,os)
      name = "Delta"
      minutes=0
      os=17
      BalancerUtil.update_stats(name, minutes,os)

    else
      Logger.error("Hailstorm mode is not enabled, you cannot run the fakedata task")
    end
  end



  #root_user is used to copy password and hash
  # returns nil if user exists
  defp make_user(name, root_user, day \\ 0, minutes \\ 0) do
    case Teiserver.Account.UserCacheLib.get_user_by_name("Alpha") do
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
          roles: ["Verified"],
          data: %{
            lobby_client: "FakeData",
            bot: false,
            password_hash: root_user.data["password_hash"]
          },
          inserted_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert,
          updated_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert
        }

        #Handle not nil
      _ ->
        Logger.info("#{name} already exists")
        nil
    end

  end

  defp make_accounts() do
    root_user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")


    #Create users that aren't random
    fixed_names = ["Alpha", "Bravo", "Charlie", "Delta"]
    fixed_users = fixed_names |> Enum.map(fn x-> make_user(x, root_user) end)
    |> Enum.filter(fn x-> x != nil end)

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

end
