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
  def perform(%{args: %{user_id: user_id}} = _job) do
    actions = Moderation.list_actions(
      search: [
        target_id: user_id,
        expiry: "All active"
      ],
      select: [:restrictions, :expires],
      limit: :infinity
    )

    if not Enum.empty?(actions) do
      new_restrictions = actions
        |> Enum.map(fn a -> a.restrictions end)
        |> List.flatten
        |> Enum.uniq

      new_restricted_until = actions
        |> Enum.map(fn a -> a.expires end)
        |> List.flatten
        |> Enum.sort(&>=/2)
        |> hd

      expires_as_string = new_restricted_until |> Jason.encode! |> Jason.decode!

      Account.update_cache_user(user_id, %{
        restrictions: new_restrictions,
        restricted_until: expires_as_string
      })
      client = Account.get_client_by_id(user_id)

      if client do
        if Enum.member?(new_restrictions, "All chat") or Enum.member?(new_restrictions, "Battle chat") do
          Coordinator.send_to_host(client.lobby_id, "!mute #{client.name}")
        end

        if Enum.member?(new_restrictions, "Login") do
          Teiserver.Client.disconnect(user_id, "Banned")
        end
      end
    end
    :ok
  end

  @spec refresh_user(T.userid()) :: :ok
  def refresh_user(user_id) do
    perform(%{args: %{user_id: user_id}})
  end
end
