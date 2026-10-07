defmodule Teiserver.Account.Registration do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.CacheUser
  alias Teiserver.Data.Types, as: T
  alias Teiserver.EmailHelper
  alias Teiserver.Geoip
  alias Teiserver.Moderation
  alias Teiserver.Moderation.Tasks.ExternalIPCheckTask

  require Logger

  @default_colour "#666666"
  @default_icon "fa-solid fa-user"

  def user_register_params_with_md5(name, email, md5_password, extra_data \\ %{}) do
    data =
      Account.default_data()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: md5_password,
      colour: @default_colour,
      icon: @default_icon,
      roles: ["Verified"],
      permissions: ["Verified"],
      data:
        data
        |> Map.merge(extra_data)
    }
  end

  @spec register_user_with_md5(String.t(), String.t(), String.t(), String.t()) ::
          :success | {:error, String.t()}
  def register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    with :ok <- Account.valid_name?(name),
         :ok <- Account.valid_email?(email),
         {:ok, _user} <-
           Account.register_user(
             %{
               "name" => String.trim(name),
               "email" => String.trim(email),
               "password" => md5_password,
               "icon" => @default_icon,
               "colour" => @default_colour,
               # hack so that we can use the same code for web and chobby registration
               # chobby does its own confirmation check
               "password_confirmation" => md5_password
             },
             :md5_password,
             ip
           ) do
      :success
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        case changeset.errors[:email] do
          nil -> {:error, "User creation failed"}
          _email_error -> {:error, "Email already attached to a user"}
        end

      {:error, reason} when is_binary(reason) ->
        {:error, reason}
    end
  end

  @doc """
  Augment the user objects with various attributes like ip or icon.
  Also handle the verification process.

  This isn't ideal as it swallows errors from verification. Adding data like ip
  after the fact is also backward and should be provided at user creation when
  available instead of patching things up after the fact.
  That however is a bigger refactor than I'm willing to make now
  """
  @spec post_user_creation_actions(user :: term(), String.t() | nil) :: T.user()
  def post_user_creation_actions(user, ip \\ nil) do
    Account.update_user_stat(user.id, %{
      "first_ip" => ip,
      "country" => Geoip.get_flag(ip),
      "verification_code" => (:rand.uniform(899_999) + 100_000) |> to_string()
    })

    ip_check_results = ExternalIPCheckTask.get_ban_reasons(ip)

    unless Enum.empty?(ip_check_results) do
      Account.update_user_stat(user.id, %{
        "ip_check_results" => Enum.join(ip_check_results, ", "),
        "ip_check_bad?" => true
      })
    end

    if Moderation.banned_ip?(ip) do
      Account.update_user_stat(user.id, %{
        "banned_ip?" => true
      })
    end

    if Moderation.vpn_ip?(ip) do
      Account.update_user_stat(user.id, %{
        "vpn_ip?" => true
      })
    end

    # Now add them to the cache
    user
    |> UserCacheLib.convert_user()
    |> UserCacheLib.add_user()

    if not String.ends_with?(user.email, "@agents") do
      case EmailHelper.new_user(user) do
        {:error, error} ->
          Logger.error("Error sending new user email - #{user.email} - #{Kernel.inspect(error)}")

        :no_verify ->
          Account.verify_user(user.id)
          :ok

        :ok ->
          :ok
      end
    end

    user
  end

  def register_bot(bot_name, bot_host_id) do
    existing_bot = Account.get_user_by_name(bot_name)

    cond do
      CacheUser.allow?(bot_host_id, :moderator) == false ->
        {:error, "no permission"}

      existing_bot != nil ->
        existing_bot

      true ->
        host = Account.get_user_by_id(bot_host_id)

        params =
          user_register_params_with_md5(bot_name, host.email, host.password)
          |> Map.merge(%{
            roles: ["Verified", "Bot"],
            email: String.replace(host.email, "@", ".bot#{bot_name}@")
          })

        case Account.script_create_user(params, :hash) do
          {:ok, user} ->
            # Now add them to the cache
            user
            |> UserCacheLib.convert_user()
            |> UserCacheLib.add_user()

          {:error, changeset} ->
            Logger.error(
              "Unable to create bot with params #{Kernel.inspect(params)}\n#{Kernel.inspect(changeset)} in register_bot(#{bot_name}, #{bot_host_id})"
            )
        end
    end
  end
end
