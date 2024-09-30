defmodule Teiserver.Account.User do
  @moduledoc false
  use TeiserverWeb, :schema
  @behaviour Bodyguard.Policy

  alias Argon2

  # TODO: this is where a user should be defined. This is only a placeholder for now
  @type t :: term()

  schema "account_users" do
    field :name, :string
    field :email, :string
    field :password, :string

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
    field :last_login_timex, :utc_datetime
    field :last_played, :utc_datetime
    field :last_logout, :utc_datetime

    field :discord_id, :integer
    field :discord_dm_channel_id, :integer
    field :steam_id, :integer

    has_many :user_configs, Teiserver.Config.UserConfig

    # Extra user.ex relations go here
    belongs_to :clan, Teiserver.Clans.Clan
    belongs_to :smurf_of, Teiserver.Account.User

    has_one :user_stat, Teiserver.Account.UserStat

    field :behaviour_score, :integer, default: 10_000
    field :trust_score, :integer, default: 10_000
    field :social_score, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    attrs =
      attrs
      |> remove_whitespace([:email])
      |> uniq_lists(~w(permissions roles)a)

    if attrs["password"] == "" do
      user
      |> cast(
        attrs,
        ~w(name email icon colour data roles permissions restrictions restricted_until shadowbanned last_login last_login_timex last_played last_logout discord_id discord_dm_channel_id steam_id smurf_of_id clan_id behaviour_score trust_score social_score)a
      )
      |> validate_required([:name, :email, :permissions])
      |> unique_constraint(:email)
    else
      user
      |> cast(
        attrs,
        ~w(name email password icon colour data roles permissions restrictions restricted_until shadowbanned last_login_timex last_login last_played last_logout discord_id discord_dm_channel_id steam_id smurf_of_id clan_id behaviour_score trust_score social_score)a
      )
      |> validate_required([:name, :email, :password, :permissions])
      |> unique_constraint(:email)
      |> put_password_hash()
    end
  end

  def changeset(user, attrs, :script) do
    attrs =
      attrs
      |> remove_whitespace([:email])
      |> uniq_lists(~w(permissions roles)a)

    user
    |> cast(
      attrs,
      ~w(name email password icon colour data roles permissions restrictions restricted_until shadowbanned last_login_timex last_login last_played last_logout discord_id discord_dm_channel_id steam_id smurf_of_id clan_id behaviour_score trust_score social_score)a
    )
    |> validate_required([:name, :email, :permissions])
    |> unique_constraint(:email)
  end

  def changeset(struct, params, nil), do: changeset(struct, params)

  def changeset(struct, permissions, :permissions) do
    cast(struct, %{permissions: permissions}, [:permissions])
  end

  def changeset(user, attrs, :self_create) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
    |> change_password(attrs)
  end

  def changeset(user, attrs, :limited) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    user
    |> cast(attrs, ~w(name email icon colour clan_id behaviour_score trust_score)a)
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end

  def changeset(user, attrs, :server_limited_update_user) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    user
    |> cast(
      attrs,
      ~w(name email icon colour clan_id behaviour_score trust_score data roles permissions)a
    )
    |> validate_required(~w(name email)a)
    |> unique_constraint(:email)
  end

  def changeset(user, attrs, :limited_with_data) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    user
    |> cast(attrs, ~w(name email icon colour data clan_id behaviour_score trust_score)a)
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end

  def changeset(user, attrs, :user_form) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    cond do
      attrs["password"] == nil or attrs["password"] == "" ->
        user
        |> cast(attrs, [:name, :email])
        |> validate_required([:name, :email])
        |> add_error(
          :password_confirmation,
          "Please enter your password to change your account details."
        )

      verify_any_password(attrs["password"], user.password) == false ->
        user
        |> cast(attrs, [:name, :email])
        |> validate_required([:name, :email])
        |> add_error(:password_confirmation, "Incorrect password")

      true ->
        user
        |> cast(attrs, [:name, :email])
        |> validate_required([:name, :email])
        |> unique_constraint(:email)
    end
  end

  def changeset(user, attrs, :password) do
    cond do
      attrs["existing"] == nil or attrs["existing"] == "" ->
        user
        |> change_password(attrs)
        |> add_error(
          :password_confirmation,
          "Please enter your existing password to change your password."
        )

      verify_any_password(attrs["existing"], user.password) == false ->
        user
        |> change_password(attrs)
        |> add_error(:existing, "Incorrect password")

      true ->
        user
        |> change_password(attrs)
    end
  end

  defp change_password(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_length(:password, min: 6)
    |> validate_confirmation(:password, message: "Does not match password")
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password: Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  @spec verify_password(String.t(), String.t()) :: boolean
  def verify_password(plain_text_password, encrypted) do
    Argon2.verify_pass(plain_text_password, encrypted)
  end

  @spec verify_md5_password(String.t(), String.t()) :: boolean
  def verify_md5_password(plain_text_password, encrypted) do
    Teiserver.CacheUser.spring_md5_password(plain_text_password)
    |> verify_password(encrypted)
  end

  @spec verify_md5_password(String.t(), String.t()) :: boolean
  def verify_any_password(plain_text_password, encrypted) do
    verify_password(plain_text_password, encrypted) or
      verify_md5_password(plain_text_password, encrypted)
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: allow?(conn, "admin.user")
  # def authorize(_, _, _), do: false
end
