defmodule Teiserver.Moderation.RefreshUserRestrictionsTask do
  @moduledoc """
  Refreshes the restrictions applied to a user based on the outstanding actions.
  """
  use Oban.Worker, queue: :teiserver
  require Logger
  alias Teiserver.Data.Types, as: T

  alias Teiserver.{Account, Coordinator, Moderation}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") ==
         true do
      now_as_string = Timex.now() |> Jason.encode!() |> Jason.decode!()

      # Find all users who are muted or banned
      # we have these anti-nil things to handle if the job
      # runs just after startup the users may not be in the cache
      Account.list_users(
        search: [
          data_less_than: {"restricted_until", now_as_string}
        ],
        select: [:id]
      )
      |> Enum.each(fn %{id: userid} ->
        refresh_user(userid)
      end)
    end

    :ok
  end

  @spec refresh_user(T.userid()) :: :ok
  def refresh_user(user_id) do
    actions =
      Moderation.list_actions(
        search: [
          target_id: user_id,
          expiry: "All active"
        ],
        select: [:restrictions, :expires],
        limit: :infinity
      )

    if Enum.empty?(actions) do
      Logger.info("Lifted remaining restrictions for user##{user_id}")

      Account.update_cache_user(user_id, %{
        restrictions: [],
        restricted_until: nil
      })
    else
      new_restrictions =
        actions
        |> Enum.map(fn a -> a.restrictions end)
        |> List.flatten()
        |> Enum.uniq()

      new_restricted_until =
        actions
        |> Enum.map(fn a -> a.expires end)
        |> List.flatten()
        |> Enum.reduce(nil, fn
          dt1, nil ->
            dt1

          dt1, dt2 ->
            if Timex.compare(dt1, dt2) == -1, do: dt1, else: dt2
        end)

      expires_as_string = new_restricted_until |> Jason.encode!() |> Jason.decode!()

      Account.update_cache_user(user_id, %{
        restrictions: new_restrictions,
        restricted_until: expires_as_string
      })

      Logger.info(
        "Update restrictions for user##{user_id} to #{Kernel.inspect(new_restrictions)} to expire at #{expires_as_string}"
      )

      client = Account.get_client_by_id(user_id)

      if client do
        update_client_with_restrictions(client, new_restrictions)
      end
    end
  end

  defp update_client_with_restrictions(client, new_restrictions) do
    Account.recache_user(client.userid)

    if Enum.member?(new_restrictions, "All chat") or Enum.member?(new_restrictions, "Battle chat") do
      Coordinator.send_to_host(client.lobby_id, "!mute #{client.name}")
    end

    cond do
      Enum.member?(new_restrictions, "Login") ->
        Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")
        Teiserver.Client.disconnect(client.userid, "Banned")

      Enum.member?(new_restrictions, "All lobbies") ->
        Coordinator.send_to_host(client.lobby_id, "!bkick #{client.name}")

      true ->
        pid = Coordinator.get_coordinator_pid()
        send(pid, {:do_client_inout, :login, client.userid})
    end
  end
end
