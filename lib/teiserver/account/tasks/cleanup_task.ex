defmodule Teiserver.Account.Tasks.CleanupTask do
  use Oban.Worker, queue: :cleanup
  alias Central.Helpers.TimexHelper
  alias Teiserver.{User, Account}
  require Logger

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") == true do
      now_as_string = Timex.now() |> Jason.encode! |> Jason.decode!

      # Find all users who are muted or banned
      # we have these anti-nil things to handle if the job
      # runs just after startup the users may not be in the cache
      Account.list_users(
        search: [
          # data_not: {"restricted_until", nil},
          data_less_than: {"restricted_until", now_as_string},
        ],
        select: [:id]
      )
      |> Enum.each(fn %{id: userid} ->
        user = User.get_user_by_id(userid)
        {expires, restrictions} = recalculate_restrictions(userid)
        User.update_user(%{user | restricted_until: expires, restrictions: restrictions}, persist: true)

        Logger.info("Update restrictions for #{user.name}/#{user.id} to #{Kernel.inspect restrictions} to expire at #{expires}")
      end)
    end

    :ok
  end

  def recalculate_restrictions(userid) do
    now = Timex.now()
    never = Timex.now() |> Timex.shift(years: 1)

    {expires, restrictions} = Account.list_reports(search: [
      target_id: userid,
      expired: false,
      filter: "closed"
    ])
    |> Enum.reduce({Timex.shift(now, years: 1), []}, fn (report, {expires, restriction_list}) ->
      {
        TimexHelper.datetime_min(report.expires || never, expires),
        restriction_list ++ (report.action_data["restriction_list"] || [])
      }
    end)

    # If expires is after now then we use that, if not it's now nil!
    # we encode/decode it to ensure the formatting is consistent
    expires = if Timex.compare(now, expires) == -1 and not Enum.empty?(restrictions), do: expires
    expires = expires |> Jason.encode!() |> Jason.decode!()

    {expires, Enum.uniq(restrictions)}
  end
end
