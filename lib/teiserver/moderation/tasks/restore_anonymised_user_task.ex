defmodule Teiserver.Moderation.RestoreAnonymisedUserTask do
  @moduledoc """
  The flip side of CreateAntiAbuseRecordTask, given an anti-abuse record
  restore soome of the user details using the decryption key.

  We use an identifier (email, discord_id, steam_id) and look for a record with the
  hashed value of said identifier. With said identifier we can then retrieve the `encryption_key` which allows us to then decrypt the data used to restore the User.

  At this stage we do not actually restore the User.

  See CreateAntiAbuseRecordTask for more information about the creation/storage process.
  """
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
    |> Repo.one()
  end

  def find_record_from_identifier(:discord_id, discord_id) do
    lookup_value =
      discord_id
      |> key_from_string()
      |> Base.encode64()

    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_identifier("discord_id", lookup_value)
    |> Repo.one()
  end

  def find_record_from_identifier(:steam_id, steam_id) do
    lookup_value =
      steam_id
      |> key_from_string()
      |> Base.encode64()

    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_identifier("steam_id", lookup_value)
    |> Repo.one()
  end

  defp retrieve_data_from_record(%AntiAbuseRecord{} = record, encryption_key) do
    # Now we have the encryption_key
    record.hashes["restore_data"]
    |> CreateAntiAbuseRecordTask.aes_decrypt(encryption_key)
    |> Jason.decode!()
  end

  def restore_from_record(%AntiAbuseRecord{} = record, identifier_type, identifier_value) do
    key_from_identifier = key_from_string(identifier_value)

    encryption_key =
      record.hashes["decrypt_keys"]
      |> Map.get(to_string(identifier_type))
      |> CreateAntiAbuseRecordTask.aes_decrypt(key_from_identifier)

    data = retrieve_data_from_record(record, encryption_key)

    # We do not currently actually restore the data, this will
    # come with a later update. For now we return the data to show
    # this has worked.
    data
  end
end
