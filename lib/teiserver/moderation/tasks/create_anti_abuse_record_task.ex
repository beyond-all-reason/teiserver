defmodule Teiserver.Moderation.CreateAntiAbuseRecordTask do
  @moduledoc """
  Given a user, create an Anti-Abuse record.

  The core data (smurf keys, avoids etc) is stored as an encrypted blob of JSON. If we have
  `encryption_key` we are able to decrypt it at a later stage, without `encryption_key`
  we cannot decrypt it.

  We then store `encryption_key` encrypted by each of the different identifiers
  (email, discord, steam) meaning a user is able to restore their data through use
  of said identifier but without the correct identifier you are unable to unlock and
  thus access the data.

  For more information about the Decryption process, see RestoreForgottenUserTask
  """
  alias Teiserver.Account
  alias Teiserver.Account.Scope
  alias Teiserver.Account.SmurfKeyQueries
  alias Teiserver.Account.User
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Microblog.PostQueries
  alias Teiserver.Microblog.UploadQueries
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Repo

  @aad "teiserver-anti-abuse"

  # A static salt so we can search the table based on a unique identifier for restoration
  # if needed
  @salt <<140, 38, 122, 4, 158, 123, 156, 216, 168, 10, 242, 248, 51, 40, 202, 130>>

  @spec create_anti_abuse_record_from_user_id(User.id(), Scope.t(), String.t()) ::
          {:ok, AntiAbuseRecord.t()} | {:error, any()}
  def create_anti_abuse_record_from_user_id(user_id, %Scope{} = scope, notes) do
    %User{} = user = Account.get_user!(user_id)

    # The key we will use to encrypt the data in the record
    encryption_key = :crypto.strong_rand_bytes(32)

    # The main data in the record
    restore_data =
      get_restore_data(user)
      |> Jason.encode!()
      |> aes_encrypt(encryption_key)

    # The user is considered clean if they have no active restrictions on their account
    clean? = Enum.empty?(user.restrictions)

    # If clean record then expire in 2 years, if not then
    # expire in 5 years or when the restriction expires
    expires_at =
      if clean? do
        DateTime.utc_now()
        |> DateTime.shift(year: 2)
      else
        five_years =
          DateTime.utc_now()
          |> DateTime.shift(year: 5)

        # Whichever is greater is the one we use
        if DateTime.compare(five_years, user.restricted_until) == :gt do
          five_years
        else
          user.restricted_until
        end
      end

    # To allow us to retrieve the encryption_key we will encrypt it once for every identifier
    # we have, we need to make keys from each of the identifiers for the encryption process
    email_key = key_from_string(user.email)
    discord_key = user.discord_id && key_from_string(to_string(user.discord_id))
    steam_key = user.steam_id && key_from_string(to_string(user.steam_id))

    hashes = %{
      email: Base.encode64(email_key),
      discord_id: discord_key && Base.encode64(discord_key),
      steam_id: steam_key && Base.encode64(steam_key),
      decrypt_keys: %{
        email: aes_encrypt(encryption_key, email_key),
        discord_id: discord_key && aes_encrypt(encryption_key, discord_key),
        steam_id: steam_key && aes_encrypt(encryption_key, steam_key)
      },
      restore_data: restore_data
    }

    # The attributes we will be using to create the record
    attrs = %{
      user_id: user_id,
      expires_at: expires_at,
      clean: clean?,
      hashes: hashes,
      notes: notes
    }

    Moderation.create_anti_abuse_record(attrs, scope)
  end

  def get_restore_data(%User{id: id} = _user) do
    smurf_key_ids =
      SmurfKeyQueries.smurf_keys()
      |> SmurfKeyQueries.where_user_id(id)
      |> QueryHelpers.query_select([:id])
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> Enum.sort()

    post_ids =
      PostQueries.posts()
      |> PostQueries.where_poster_id(id)
      |> QueryHelpers.query_select([:id])
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> Enum.sort()

    upload_ids =
      UploadQueries.uploads()
      |> UploadQueries.where_uploader_id(id)
      |> QueryHelpers.query_select([:id])
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> Enum.sort()

    %{
      smurf_key_ids: smurf_key_ids,
      post_ids: post_ids,
      upload_ids: upload_ids
    }
  end

  @doc """
  Used to create an AES encryption key from a given string.
  """
  def key_from_string(key) do
    :crypto.pbkdf2_hmac(
      :sha256,
      key,
      @salt,
      600_000,
      32
    )
  end

  @doc """
  Given a message and encryption key will return an encrypted message.
  """
  def aes_encrypt(message, key) when byte_size(key) == 32 do
    # Using an initialisation vector means even if we encrypted
    # the same value multiple times we will get a different ciphertext
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        key,
        iv,
        message,
        @aad,
        true
      )

    Base.encode64(iv <> tag <> ciphertext)
  end

  @doc """
  Inverse to aes_encrypt, given encrypted data and a key it will
  decrypt the data.
  """
  def aes_decrypt(encoded_data, key) when byte_size(key) == 32 do
    <<iv::binary-size(12), tag::binary-size(16), ciphertext::binary>> =
      Base.decode64!(encoded_data)

    :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      key,
      iv,
      ciphertext,
      @aad,
      tag,
      false
    )
  end
end
