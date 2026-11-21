defmodule Teiserver.Account.PopulationReport do
  @moduledoc false
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Repo
  import Ecto.Query

  @spec compose_users_query_by_params(binary(), binary(), binary()) :: Ecto.Query.t()
  def compose_users_query_by_params(last_login, registered, exclude_bots) do
    UserQueries.users()
    |> maybe_pass_registered(registered)
    |> maybe_pass_last_login(last_login)
    |> maybe_exclude_bots(exclude_bots)
  end

  @spec count_by_field(Ecto.Query.t(), binary()) :: {non_neg_integer(), list(map())}
  def count_by_field(query, field) do
    total = Repo.aggregate(query, :count, :id)

    data =
      extract_ids_with_field(query, field)
      |> group_by_field_and_count()
      |> Repo.all()

    {total, data}
  end

  defp extract_ids_with_field(query, field) do
    from u in query,
      left_join: us in assoc(u, :user_stat),
      select: %{
        id: u.id,
        field: fragment("?->>?", us.data, ^field)
      }
  end

  defp group_by_field_and_count(query) do
    from extracted in subquery(query),
      group_by: extracted.field,
      order_by: [desc: count(extracted.id)],
      select: %{
        field: extracted.field,
        count: count(extracted.id)
      }
  end

  defp maybe_pass_last_login(query, "Ignore"), do: query

  defp maybe_pass_last_login(query, last_login) do
    {last_login_after, last_login_before} = DatePresets.parse(last_login, "", "")

    query
    |> UserQueries.where_logged_in_after(last_login_after)
    |> UserQueries.where_logged_in_before(last_login_before)
  end

  defp maybe_pass_registered(query, "Ignore"), do: query

  defp maybe_pass_registered(query, registered) do
    {registered_after, registered_before} = DatePresets.parse(registered, "", "")

    query
    |> UserQueries.where_registered_before(
      DateTime.new!(registered_before, ~T"00:00:00", "Etc/UTC")
    )
    |> UserQueries.where_registered_after(
      DateTime.new!(registered_after, ~T"00:00:00", "Etc/UTC")
    )
  end

  defp maybe_exclude_bots(query, "true") do
    query
    |> UserQueries.where_not_has_role("Bot")
  end

  defp maybe_exclude_bots(query, "false") do
    query
  end

  defp maybe_exclude_bots(query, _value), do: query
end
