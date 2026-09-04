defmodule Teiserver.Account.User do
  @moduledoc false

  alias Argon2
  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.CacheUser
  alias Teiserver.Helper.StylingHelper

  use TeiserverWeb, :schema

  @behaviour Bodyguard.Policy

  @type id :: pos_integer()

  typed_schema "account_users" do
    field :name, :string
    field :email, :string
    field :previous_emails, {:array, :string}, default: []
    field :password, :string, redact: true

    field :icon, :string
    field :colour, :string

    field :data, :map, default: %{}

    field :roles, {:array, :string}, default: []
    field :permissions, {:array, :string}, default: []

    field :restrictions, {:array, :string}, default: []
    field :restricted_until, :utc_datetime

    field :shadowbanned, :boolean, default: false

    # Start time of their last match
    field :last_login, :utc_datetime
    field :last_played, :utc_datetime
    field :last_logout, :utc_datetime
    field :email_last_changed_at, :utc_datetime

    field :discord_id, :integer
    field :discord_dm_channel_id, :integer
    field :steam_id, :integer

    field :rank, :integer, default: 0
    field :country, :string, default: "??"
    field :bot, :boolean, default: false
    field :email_change_code, :string
    field :lobby_hash, :string
    field :chobby_hash, :string
    field :lobby_client, :string
    field :discord_dm_channel, :integer

    has_many :user_configs, Teiserver.Config.UserConfig

    # Extra user.ex relations go here
    belongs_to :smurf_of, Teiserver.Account.User

    has_one :user_stat, Teiserver.Account.UserStat

    timestamps()
  end

  def default_data do
    %{
      rank: 0,
      country: "??",
      bot: false,
      email_change_code: nil,
      last_login: nil,
      restrictions: [],
      restricted_until: nil,
      shadowbanned: false,
      lobby_hash: nil,
      chobby_hash: nil,
      discord_id: nil,
      discord_dm_channel: nil,
      discord_dm_channel_id: nil,
      steam_id: nil
    }
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    attrs =
      attrs
      |> remove_whitespace([:email])
      |> uniq_lists(~w(permissions roles)a)

    user
    |> cast(
      attrs,
      ~w(name email password icon colour data roles permissions restrictions restricted_until shadowbanned last_login last_played last_logout discord_id discord_dm_channel_id steam_id country bot email_change_code lobby_hash chobby_hash lobby_client discord_dm_channel)a
    )
    |> validate_required([:name, :email, :password, :permissions])
    |> unique_constraint(:email)
    |> validate_name_change()
    |> put_md5_password_hash()
  end

  def changeset(user, attrs, :script) do
    attrs =
      attrs
      |> remove_whitespace([:email])
      |> uniq_lists(~w(permissions roles)a)

    user
    |> cast(
      attrs,
      ~w(name email password icon colour data roles permissions restrictions restricted_until shadowbanned last_login last_played last_logout discord_id discord_dm_channel_id steam_id rank country bot email_change_code lobby_hash chobby_hash lobby_client discord_dm_channel)a
    )
    |> validate_required([:name, :email, :password, :permissions])
    |> unique_constraint(:email)
    |> validate_change(:email, fn :email, email ->
      case CacheUser.valid_email?(email) do
        :ok -> []
        {:error, reason} -> [{:email, reason}]
      end
    end)
    |> validate_name_change()
    |> put_md5_password_hash()
  end

  def changeset(struct, params, nil), do: changeset(struct, params)

  def changeset(struct, permissions, :permissions) do
    cast(struct, %{permissions: permissions}, [:permissions])
  end

  def changeset(user, attrs, :admin_update_user) do
    user
    |> cast(
      attrs,
      ~w(name email icon colour data roles permissions)a
    )
    |> validate_required([:name])
    |> validate_name_change()
  end

  def changeset(user, attrs, :senior_moderator_update_user) do
    user
    |> cast(
      attrs,
      ~w(name email icon colour data roles permissions)a
    )
    |> validate_required([:name])
    |> validate_name_change()
  end

  def changeset(user, attrs, :moderator_update_user) do
    user
    |> cast(
      attrs,
      ~w(name icon colour data roles permissions)a
    )
    |> validate_required([:name])
    |> validate_name_change()
  end

  def changeset(user, attrs, :limited_with_data) do
    user
    |> cast(attrs, ~w(name icon colour data)a)
    |> validate_required([:name])
    |> validate_name_change()
  end

  # Requires the password to be used for email address changes
  def changeset(%User{email: old_email} = user, attrs, :email) do
    attrs = remove_whitespace(attrs, [:email])

    new_previous_emails = [old_email | user.previous_emails || []]

    if Account.verify_plain_password(attrs["password"] || "", user.password) do
      user
      |> cast(attrs, [:email])
      |> cast(
        %{previous_emails: new_previous_emails, email_last_changed_at: DateTime.utc_now()},
        [
          :previous_emails,
          :email_last_changed_at
        ]
      )
      |> validate_required([:email, :previous_emails])
      |> unique_constraint(:email)
      |> validate_change(:email, fn :email, email ->
        case CacheUser.valid_email?(email) do
          :ok -> []
          {:error, reason} -> [{:email, reason}]
        end
      end)
    else
      user
      |> cast(attrs, [:email])
      |> add_error(:password, "Incorrect password")
    end
  end

  # Updating password from password change form
  # New password is in plain text
  # Requires existing password confirmation
  def changeset(user, attrs, :password) do
    cond do
      attrs["existing"] == nil or attrs["existing"] == "" ->
        user
        |> change_plain_password(attrs)
        |> add_error(
          :password_confirmation,
          "Please enter your existing password to change your password."
        )

      Account.verify_plain_password(attrs["existing"], user.password) == false ->
        user
        |> change_plain_password(attrs)
        |> add_error(:existing, "Incorrect password")

      true ->
        user
        |> change_plain_password(attrs)
    end
  end

  # Updating password from password reset form doesn't require existing password
  def changeset(user, attrs, :password_reset) do
    user
    |> cast(attrs, [:password])
    |> validate_password()
    |> validate_confirmation(:password, message: "Passwords do not match")
    |> put_plain_password_hash()
  end

  def changeset(user, attrs, :script_create, password_type) do
    # this is a bit of a hack to allow this changeset to be called from
    # both code (with atoms) and from admin API (with strings)
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    data =
      default_data()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.merge(Map.get(attrs, "data", %{}))

    attrs =
      Map.merge(
        %{
          "icon" => "fa-solid fa-" <> StylingHelper.random_icon(),
          "colour" => StylingHelper.random_colour()
        },
        attrs
      )
      |> Map.put("data", data)
      |> remove_whitespace([:email])
      |> uniq_lists(~w(permissions roles)a)

    user
    |> cast(
      attrs,
      ~w(name email password icon colour data roles permissions restrictions restricted_until shadowbanned last_login last_played last_logout discord_id discord_dm_channel_id steam_id)a
    )
    |> validate_required([:name, :email, :password, :permissions])
    |> unique_constraint(:email)
    |> validate_change(:email, fn :email, email ->
      case CacheUser.valid_email?(email) do
        :ok -> []
        {:error, reason} -> [{:email, reason}]
      end
    end)
    |> validate_name_change()
    |> then(fn changeset ->
      case password_type do
        :plain_password -> put_plain_password_hash(changeset)
        :md5_password -> put_md5_password_hash(changeset)
        # Used when registering bots, the bot owner's password
        # hash is passed and should be stored directly
        :hash -> changeset
      end
    end)
  end

  def changeset(user, attrs, :register, password_type) do
    attrs = remove_whitespace(attrs, [:email])

    data = default_data() |> Map.new(fn {k, v} -> {to_string(k), v} end)

    attrs =
      Map.merge(
        %{
          "icon" => "fa-solid fa-" <> StylingHelper.random_icon(),
          "colour" => StylingHelper.random_colour()
        },
        attrs
      )
      |> Map.put("data", data)

    user
    |> cast(attrs, [:name, :email, :password, :icon, :colour, :data])
    |> unique_constraint(:email)
    |> validate_required([:name, :email, :password])
    |> validate_confirmation(:password, required: true, message: "Passwords do not match")
    |> validate_name_change()
    |> validate_password()
    |> validate_change(:email, fn :email, email ->
      case CacheUser.valid_email?(email) do
        :ok -> []
        {:error, reason} -> [{:email, reason}]
      end
    end)
    |> then(fn changeset ->
      case password_type do
        :plain_password -> put_plain_password_hash(changeset)
        :md5_password -> put_md5_password_hash(changeset)
      end
    end)
  end

  def smurf_changeset(%User{} = user, attrs) do
    cast(user, attrs, [:smurf_of_id])
  end

  defp change_plain_password(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_password()
    |> validate_confirmation(:password, message: "Does not match password")
    |> put_plain_password_hash()
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6)
    |> validate_exclusion(:password, ["1B2M2Y8AsgTpgAmY7PhCfg=="],
      message: "password not allowed (legacy empty chobby pass)"
    )
  end

  defp put_plain_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset,
      password: Account.spring_md5_password(password) |> Account.hash_password()
    )
  end

  defp put_plain_password_hash(changeset), do: changeset

  defp put_md5_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password: Account.hash_password(password))
  end

  defp put_md5_password_hash(changeset), do: changeset

  defp validate_name_change(%Changeset{} = changeset) do
    changeset
    |> validate_change(:name, fn :name, name ->
      case Account.valid_name?(name, false) do
        :ok -> []
        {:error, reason} -> [{:name, reason}]
      end
    end)
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_action, conn, _data), do: allow?(conn, "admin.user")

  @doc """
  Ensure the user id is at least somewhat correct
  """
  @spec parse_user_id(id() | String.t()) :: {:ok, id()} | {:error, reason :: term()}
  def parse_user_id(user_id) when is_integer(user_id) do
    # this is a postgres constraint since user id are also bigints
    bigint_max = Integer.pow(2, 63) - 1

    if user_id >= 0 && user_id < bigint_max do
      {:ok, user_id}
    else
      {:error, :out_of_range}
    end
  end

  def parse_user_id(user_id) when is_binary(user_id) do
    case user_id |> String.trim() |> Integer.parse() do
      {id, ""} -> parse_user_id(id)
      _err -> {:error, :invalid}
    end
  end

  def parse_user_id(_user_id), do: {:error, :invalid}
end
