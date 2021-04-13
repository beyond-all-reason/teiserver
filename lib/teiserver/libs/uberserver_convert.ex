defmodule Teiserver.UberserverConvert do
  use Oban.Worker, queue: :teiserver
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Central.Logging.Helpers
  require Logger

  @impl Oban.Worker
  @spec perform(Map.t()) :: :ok
  def perform(%{args: %{"body" => body}}) do
    id = UUID.uuid4()
    start_time = :erlang.system_time(:seconds)
    Helpers.add_anonymous_audit_log("Teiserver.UberserverConvert started", %{id: id})
    create_conversion_job(body)
    time_taken = :erlang.system_time(:seconds) - start_time
    Helpers.add_anonymous_audit_log("Teiserver.UberserverConvert completed", %{id: id, time_taken: time_taken})

    :ok
  end

  @spec create_conversion_job(String.t()) :: :ok
  defp create_conversion_job(body) do
    existing_user_emails = Central.Account.list_users(
      select: [:email],
      limit: :infinity
    )
    |> Enum.map(fn u -> u.email end)

    # Json has to store keys as strings. This is a problem since they're ids
    # and we want to see them as integers
    data = Jason.decode!(body)
    |> Map.get("users")
    |> Map.new(fn {k, v} -> {int_parse(k), v} end)

    user_count = Central.Account.list_users(select: [:id], limit: :infinity)
      |> Enum.count()

    Logger.info("UberserverConvert data parsed, user count = #{user_count}")

    user_lookup = data
    |> Enum.map(fn {ubid, user_data} ->
      if Enum.member?(existing_user_emails, user_data["email"]) do
        update_user({ubid, user_data})
      else
        add_user({ubid, user_data})
      end
    end)
    |> Map.new

    user_count = Central.Account.list_users(select: [:id], limit: :infinity)
      |> Enum.count()

    Logger.info("UberserverConvert userlookup created of length #{Enum.count(user_lookup)}, user_count = #{user_count}")

    # Now update the users
    data
    |> Enum.map(fn {ubid, user_data} ->
      second_pass_update(user_lookup, ubid, user_data)
    end)

    Logger.info("UberserverConvert second pass performed")

    :ok
  end

  defp convert_data(raw_data) do
    bar_user_group = ConCache.get(:application_metadata_cache, "bar_user_group")

    {verified, code} = case raw_data["verification_code"] do
      nil -> {true, nil}
      c -> {false, c}
    end

    user_permissions = ["teiserver", "teiserver.player", "teiserver.player.account"]
    mod_permissions = user_permissions ++ ["teiserver.moderator", "teiserver.moderator.account", "teiserver.moderator.battle"]
    admin_permissions = mod_permissions ++ ["teiserver.admin", "teiserver.admin.account", "teiserver.admin.battle"]

    permissions = case raw_data["access"] do
      "admin" -> admin_permissions
      "mod" -> mod_permissions
      _ -> user_permissions
    end

    is_mod = case raw_data["access"] do
      "admin" -> true
      "mod" -> true
      _ -> false
    end

    %{
      name: raw_data["username"],
      email: raw_data["email"],
      password: raw_data["password"],
      permissions: permissions,
      admin_group_id: bar_user_group,
      colour: "#AA0000",
      icon: "fas fa-user",
      data: %{
        "ingame_minutes" => raw_data["ingame_time"],
        "bot" => (raw_data["bot"] == "1"),
        "moderator" => is_mod,
        "verified" => verified,
        "verification_code" => code
      }
    }
  end

  defp add_user({ubid, raw_data}) do
    bar_user_group = ConCache.get(:application_metadata_cache, "bar_user_group")
    data = convert_data(raw_data)

    {:ok, user} = Teiserver.Account.create_user(data)

    Central.Account.create_group_membership(%{
      user_id: user.id,
      group_id: bar_user_group
    })

    {ubid, user.id}
  end

  # TODO
  # Useful for performing quick updates across the users when I make a mistake
  # I'm leaving it here for now but it'll be removed at some point
  # defp update_user({ubid, raw_data}) do
  #   user_data = convert_data(raw_data)
  #   |> Map.drop([:password])

  #   user = Central.Account.get_user_by_email(user_data.email)

  #   {ubid, user.id}
  # end

  defp update_user({ubid, raw_data}) do
    # Get the data as if it's a fresh user, drop the password
    user_data = convert_data(raw_data)
    |> Map.drop([:password])

    # Now get the existing user from the database
    user = Central.Account.get_user_by_email(user_data.email)

    # Merge the existing user data with the new user data
    new_data_attr = user.data
    |> Map.merge(user_data.data)

    # Now update the entire block of "new user" data with the merged data attribute
    user_data = Map.put(user_data, :data, new_data_attr)

    # Update the user in the database
    {:ok, _user} = Teiserver.Account.update_user(user, user_data)

    # Currently we're just going to assume they are already a member of this group
    # Central.Account.create_group_membership(%{
    #   user_id: user.id,
    #   group_id: bar_user_group
    # })

    {ubid, user.id}
  end

  defp convert_ids(_, nil), do: []
  defp convert_ids(user_map, ids) do
    ids
    |> Enum.map(fn i -> user_map[i] end)
  end

  defp second_pass_update(user_map, ubid, user_data) do
    userid = user_map[ubid]
    user = Teiserver.Account.get_user!(userid)
    new_data = Map.merge(user.data, %{
      "password_hash" => user.password |> String.replace("\"", ""),
      "friends" => convert_ids(user_map, user_data["friends"]),
      "friend_requests" => convert_ids(user_map, user_data["friend_requests"]),
      "ignored" => convert_ids(user_map, user_data["ignored"]),
    })
    Teiserver.Account.update_user(user, %{data: new_data})
  end
end
