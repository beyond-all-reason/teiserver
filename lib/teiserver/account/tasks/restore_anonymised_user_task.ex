defmodule Teiserver.Account.RestoreAnonymisedUserTask do
  @moduledoc """
  The flip side of CreateAntiAbuseRecordTask, given an anti-abuse record
  restore soome of the user details using the decryption key.

  We use an identifier (email, discord_id, steam_id) and look for a record with the
  hashed value of said identifier. With said identifier we can then retrieve the `encryption_key` which allows us to then decrypt the data used to restore the User.

  At this stage we do not actually restore the User.

  See CreateAntiAbuseRecordTask for more information about the creation/storage process.
  """
  alias Ecto.Adapters.SQL
  alias Ecto.UUID
  alias Teiserver.Account
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Moderation.CreateAntiAbuseRecordTask
  alias Teiserver.Repo

  import Teiserver.Moderation.CreateAntiAbuseRecordTask, only: [key_from_string: 1]

  @spec find_record_from_identifier(:email | :steam_id | :discord_id, String.t()) ::
          {:ok, AntiAbuseRecord.t()} | {:error, String.t()}
  def find_record_from_identifier(:email, email) do
    lookup_value =
      email
      |> key_from_string()
      |> Base.encode64()

    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_identifier("email", lookup_value)
    |> AntiAbuseRecordQueries.where_restored(false)
    |> Repo.one()
  end

  def find_record_from_identifier(:discord_id, discord_id) do
    lookup_value =
      discord_id
      |> key_from_string()
      |> Base.encode64()

    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_identifier("discord_id", lookup_value)
    |> AntiAbuseRecordQueries.where_restored(false)
    |> Repo.one()
  end

  def find_record_from_identifier(:steam_id, steam_id) do
    lookup_value =
      steam_id
      |> key_from_string()
      |> Base.encode64()

    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_identifier("steam_id", lookup_value)
    |> AntiAbuseRecordQueries.where_restored(false)
    |> Repo.one()
  end

  defp retrieve_data_from_record(%AntiAbuseRecord{} = record, encryption_key) do
    # Now we have the encryption_key
    record.hashes["restore_data"]
    |> CreateAntiAbuseRecordTask.aes_decrypt(encryption_key)
    |> Jason.decode!()
  end

  def restore_from_record(
        %AntiAbuseRecord{} = record,
        %Scope{} = scope,
        identifier_type,
        identifier_value,
        perform \\ false
      ) do
    key_from_identifier = key_from_string(identifier_value)

    encryption_key =
      record.hashes["decrypt_keys"]
      |> Map.get(to_string(identifier_type))
      |> CreateAntiAbuseRecordTask.aes_decrypt(key_from_identifier)

    data = retrieve_data_from_record(record, encryption_key)

    if perform do
      Repo.transact(fn ->
        with {:ok, %User{}} <-
               do_restore_user_struct(record.user_id, identifier_type, identifier_value),
             :ok <- do_perform_restoration(record, data),
             {:ok, _record} <- mark_record_as_restored(record, scope) do
          {:ok, :success}
        end
      end)
    else
      {:ok, data}
    end
  end

  defp do_restore_user_struct(user_id, :email, email) do
    user_id
    |> Account.get_user_by_id!()
    |> Account.script_update_user(%{
      email: email,
      icon: "fa-solid fa-user",
      colour: "#666666",
      roles: ["Verified"],
      permissions: ["Verified"]
    })
  end

  defp do_restore_user_struct(user_id, :discord_id, discord_id) do
    user_id
    |> Account.get_user_by_id!()
    |> Account.script_update_user(%{
      discord_id: discord_id,
      icon: "fa-solid fa-user",
      colour: "#666666",
      roles: ["Verified"],
      permissions: ["Verified"]
    })
  end

  defp do_restore_user_struct(user_id, :steam_id, steam_id) do
    user_id
    |> Account.get_user_by_id!()
    |> Account.script_update_user(%{
      steam_id: steam_id,
      icon: "fa-solid fa-user",
      colour: "#666666",
      roles: ["Verified"],
      permissions: ["Verified"]
    })
  end

  defp do_perform_restoration(%AntiAbuseRecord{} = record, data) do
    user_id = record.user_id

    # We need to convert the UUID strings into Bytes for Postgres
    upload_ids_bytes = Enum.map(data["upload_ids"], &UUID.dump!/1)

    [
      {"microblog_posts", :poster_id, data["post_ids"]},
      {"microblog_uploads", :uploader_id, upload_ids_bytes},
      {"teiserver_account_smurf_keys", :user_id, data["smurf_key_ids"]}
    ]
    |> Enum.each(fn {table, field, ids} ->
      query = "UPDATE #{table} SET #{field} = #{user_id} WHERE id = ANY($1);"
      {:ok, _results} = SQL.query(Repo, query, [ids])
    end)
  end

  defp mark_record_as_restored(%AntiAbuseRecord{} = record, scope) do
    Moderation.update_anti_abuse_record(
      record,
      %{
        restored_by: scope.user.id,
        restored_at: DateTime.utc_now()
      },
      scope
    )
  end
end
