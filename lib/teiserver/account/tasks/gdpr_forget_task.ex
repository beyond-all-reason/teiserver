defmodule Teiserver.Account.Tasks.GdprForgetTask do
  @moduledoc """
  The purpose of this task is to clean all PII from an account (at minimum
  what GDPR requires but we want to get rid of as much as possible) without
  breaking integrity of other data.

  This means things like match membership remain because they hold no data
  as to the identity of the person and are used elsewhere for things like
  ratings.
  """

  alias Ecto.Adapters.SQL
  alias Plug.Conn
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.Logging.Helpers, as: LoggingHelpers
  alias Teiserver.Repo

  @doc """
  Given the conn of the user performing the forgetting and a user struct
  of the user being forgotten, attempt to forget the user.
  """
  @spec forget_user(Conn.t(), User.t()) :: :ok | {:error, String.t()}
  def forget_user(%Conn{} = conn, %User{id: target_id} = target) do
    case UserLib.has_access(target, conn) do
      {true, _role} ->
        case perform_forget(target) do
          {:ok, _transaction_result} ->
            LoggingHelpers.add_audit_log(conn, "gdpr-forget", %{
              target_id: target_id,
              outcome: "success"
            })

            :ok

          {:error, reason} ->
            LoggingHelpers.add_audit_log(conn, "gdpr-forget", %{
              target_id: target_id,
              outcome: "error",
              reason: reason
            })

            {:error, "Task error"}
        end

      _no_access ->
        LoggingHelpers.add_audit_log(conn, "gdpr-forget", %{
          target_id: target_id,
          outcome: "error",
          reason: "No access"
        })

        {:error, "No access"}
    end
  end

  defp perform_forget(%User{} = user) do
    Repo.transact(fn ->
      forget_user_struct(user)
      forget_user_references(user)
      {:ok, %{}}
    end)
  end

  defp forget_user_struct(%User{} = user) do
    # Wipe all the user fields that contain PII, this new user
    # is persisted via the update_cache_user call below which
    # will call the relevant changeset and update any caches
    # to prevent accidental re-population of data
    # We put the role "gdpr-forgot" so anybody viewing
    # the struct can see it has been forgotten and we can
    # audit the forgetting process if needed
    new_user =
      Map.merge(user, %{
        name:
          (Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9))
          |> Enum.take_random(20),
        email: "#{user.id}@#{user.id}.#{user.id}",
        password: UserLib.make_bot_password(),
        icon: "",
        colour: "",
        roles: ["GDPR forgotten"],
        permissions: [],
        discord_id: nil,
        discord_dm_channel_id: nil,
        steam_id: nil,
        country: "??"
      })

    # Clean a bunch of user stat details, anything that would identify them
    # we only ever store the first IP they connected from and the last hence
    # no reference of other IP addresses
    Account.delete_user_stat_keys(user.id, [
      "first_ip",
      "country",
      "last_ip",
      "previous_names",
      "discord_dm_channel",
      "colour",
      "icon"
    ])

    # Update the in-memory user to ensure that is cleared too
    Account.update_cache_user(user.id, new_user)
  end

  # We remove a set of rows in other tables which could lead us to
  # not actually forget the user
  defp forget_user_references(%User{id: user_id} = _user) do
    [
      {"account_codes", :user_id},
      {"account_friend_requests", :from_user_id},
      {"account_friend_requests", :to_user_id},
      {"account_friends", :user1_id},
      {"account_friends", :user2_id},
      {"account_relationships", :from_user_id},
      {"account_relationships", :to_user_id},
      {"account_user_tokens", :user_id},
      {"config_user", :user_id},
      {"direct_messages", :from_id},
      {"direct_messages", :to_id},
      {"microblog_poll_responses", :user_id},
      {"microblog_user_preferences", :user_id},
      {"oauth_applications", :owner_id},
      {"oauth_codes", :owner_id},
      {"oauth_tokens", :owner_id},
      {"page_view_logs", :user_id},
      {"teiserver_account_accolades", :giver_id},
      {"teiserver_account_accolades", :recipient_id},
      {"teiserver_account_user_totps", :user_id},
      {"telemetry_user_properties", :user_id}
    ]
    |> Enum.each(fn {table, field} ->
      query = "DELETE FROM #{table} WHERE #{field} = $1;"

      case SQL.query(Repo, query, [user_id]) do
        {:ok, _results} ->
          :ok

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end
    end)
  end
end
