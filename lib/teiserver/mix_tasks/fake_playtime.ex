defmodule Mix.Tasks.Teiserver.FakePlaytime do
  @moduledoc """
  Adds fake play time stats to all non bot users
  This will also be called by the teiserver.fakedata task

  If you want to run this task invidually, use:
  mix teiserver.fake_playtime
  """

  use Mix.Task
  require Logger
  alias Teiserver.{Account, CacheUser}

  def run(_args) do
    Application.ensure_all_started(:teiserver)

    Account.list_users(
      search: [
        not_has_role: "Bot"
      ],
      select: [:id, :name]
    )
    |> Enum.each(fn user ->
      update_stats(user.id, random_playtime())
    end)

    Logger.info("Finished applying fake playtime data")
  end

  def update_stats(user_id, player_minutes) do
    Account.update_user_stat(user_id, %{
      player_minutes: player_minutes,
      total_minutes: player_minutes
    })

    # Now recalculate ranks
    # This calc would usually be done in do_login
    rank = CacheUser.calculate_rank(user_id)

    Account.update_user_stat(user_id, %{
      rank: rank
    })
  end

  defp random_playtime() do
    hours =
      case get_player_experience() do
        :just_installed -> Enum.random(0..4)
        :beginner -> Enum.random(5..99)
        :average -> Enum.random(100..249)
        :pro -> Enum.random(250..1750)
      end

    hours * 60
  end

  @spec get_player_experience() :: :just_installed | :beginner | :average | :pro
  defp get_player_experience do
    case Enum.random(0..15) do
      0 -> :just_installed
      1 -> :beginner
      2 -> :average
      _ -> :pro
    end
  end
end
