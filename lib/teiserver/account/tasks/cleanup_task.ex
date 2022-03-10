defmodule Teiserver.Account.Tasks.CleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{User, Account}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if ConCache.get(:application_metadata_cache, "teiserver_full_startup_completed") == true do
      # Find all users who are muted or banned
      # we have these anti-nil things to handle if the job
      # runs just after startup the users may not be in the cache
      Account.list_users(
        search: [
          mod_action: "Any action"
        ],
        select: [:id]
      )
      |> Enum.each(fn %{id: userid} ->
        user = User.get_user_by_id(userid)

        if user do
          user
          |> check_muted()
          |> check_banned()
          |> check_warned()
          |> User.update_user(persist: true)
        end
      end)
    end

    :ok
  end

  defp check_warned(user) do
    if User.is_warned?(user) do
      user
    else
      %{user | warned: [false, nil]}
    end
  end

  defp check_muted(user) do
    if User.is_muted?(user) do
      user
    else
      %{user | muted: [false, nil]}
    end
  end

  defp check_banned(user) do
    if User.is_restricted?(user, ["Login"]) do
      user
    else
      %{user | banned: [false, nil]}
    end
  end
end
