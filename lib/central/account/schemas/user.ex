defmodule Central.Account.User do
  @moduledoc false
  use CentralWeb, :schema
  @behaviour Bodyguard.Policy

  alias Argon2

  # import Central.Account.AuthLib, only: [allow?: 2]

  @extra_fields ~w(clan_id behaviour_score trust_score)a

  schema "account_users" do
    field :name, :string
    field :email, :string
    field :password, :string

    field :icon, :string
    field :colour, :string

    field :data, :map, default: %{}

    field :permissions, {:array, :string}, default: []

    has_many :user_configs, Central.Config.UserConfig

    # Extra user.ex relations go here
    belongs_to :clan, Teiserver.Clans.Clan
    has_one :user_stat, Teiserver.Account.UserStat

    field :behaviour_score, :integer, default: 10_000
    field :trust_score, :integer, default: 10_000

    belongs_to :admin_group, Central.Account.Group

    many_to_many :groups, Central.Account.Group,
      join_through: "account_group_memberships",
      join_keys: [user_id: :id, group_id: :id]

    timestamps()
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    attrs =
      attrs
      |> remove_whitespace([:email])
      |> uniq_lists([:permissions])

    if attrs["password"] == "" do
      user
      |> cast(
        attrs,
        [:name, :email, :icon, :colour, :permissions, :admin_group_id, :data] ++ @extra_fields
      )
      |> validate_required([:name, :email, :permissions])
      |> unique_constraint(:email)
    else
      user
      |> cast(
        attrs,
        [
          :name,
          :email,
          :password,
          :icon,
          :colour,
          :permissions,
          :admin_group_id,
          :data
        ] ++ @extra_fields
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
      |> uniq_lists([:permissions])

    user
    |> cast(
      attrs,
      [
        :name,
        :email,
        :password,
        :icon,
        :colour,
        :permissions,
        :admin_group_id,
        :data
      ] ++ @extra_fields
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
    |> cast(attrs, [:name, :email, :icon, :colour] ++ @extra_fields)
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end

  def changeset(user, attrs, :limited_with_data) do
    attrs =
      attrs
      |> remove_whitespace([:email])

    user
    |> cast(attrs, [:name, :email, :icon, :colour, :data] ++ @extra_fields)
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

      verify_password(attrs["password"], user.password) == false ->
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

      verify_password(attrs["existing"], user.password) == false ->
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

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: allow?(conn, "admin.user")
  # def authorize(_, _, _), do: false
end
