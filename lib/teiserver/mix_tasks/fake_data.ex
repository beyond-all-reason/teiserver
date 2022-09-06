defmodule Mix.Tasks.Teiserver.Fakedata do
  @moduledoc """
  Run with mix teiserver.fakedata
  """

  use Mix.Task

  alias Teiserver.{Account}
  alias Central.Helpers.StylingHelper

  @settings %{
    days: 365
  }

  defp users_per_day, do: :rand.uniform(5) + 2

  @spec run(list()) :: :ok
  def run(_args) do
    # Start by rebuilding the database
    Mix.Task.run("ecto.reset")

    accounts()
    make_one_time_code()

    IO.puts "Fake data insertion complete. You can now login with the email 'root@localhost' and password 'password'\nA one-time link has been created: http://localhost:4000/one_time_login/fakedata_code"
  end

  defp add_root_user() do
    {:ok, group} =
      Central.Account.create_group(%{
        "name" => "Root group",
        "colour" => "#AA0000",
        "icon" => "fa-regular fa-info",
        "active" => true,
        "group_type" => nil,
        "data" => %{},
        "see_group" => false,
        "see_members" => false,
        "invite_members" => false,
        "self_add_members" => false,
        "super_group_id" => nil
      })

    {:ok, user} =
      Account.create_user(%{
        name: "root",
        email: "root@localhost",
        password: "password",
        permissions: ["admin.dev.developer"],
        admin_group_id: group.id,
        icon: "fa-solid fa-power-off",
        colour: "#00AA00"
      })

    Central.Account.create_group_membership(%{
      "group_id" => group.id,
      "user_id" => user.id,
      "admin" => true
    })

    user
  end

  defp accounts() do
    root_user = add_root_user()

    new_users = Range.new(0, @settings.days)
    |> Parallel.map(fn day ->
      Range.new(0, users_per_day())
      |> Parallel.map(fn _ ->
        minutes = :rand.uniform(24 * 60)

        %{
          name: Central.Account.generate_throwaway_name() |> String.replace(" ", ""),
          email: "#{UUID.uuid1()}.#{UUID.uuid4()}",
          password: root_user.password,
          permissions: ["admin.dev.developer"],
          icon: "fa-solid #{StylingHelper.random_icon}",
          colour: StylingHelper.random_colour(),
          inserted_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert,
          updated_at: Timex.shift(Timex.now(), days: -day, minutes: -minutes) |> time_convert
        }
      end)
    end)
    |> List.flatten

    Ecto.Multi.new()
      |> Ecto.Multi.insert_all(:insert_all, Central.Account.User, new_users)
      |> Central.Repo.transaction()


  end

  defp make_one_time_code() do
    root_user = Account.get_user_by_email("root@localhost")

    Central.Config.update_site_config("user.Enable one time links", "true")

    {:ok, _code} = Central.Account.create_code(%{
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
      |> Timex.to_naive_datetime
  end
end
