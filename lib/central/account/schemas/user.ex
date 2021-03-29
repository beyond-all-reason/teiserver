defmodule Central.Account.User do
  use CentralWeb, :schema
  @behaviour Bodyguard.Policy

  alias Argon2

  # import Central.Account.AuthLib, only: [allow?: 2]

  schema "account_users" do
    field :name, :string
    field :email, :string
    field :password, :string

    field :icon, :string
    field :colour, :string

    field :data, :map, default: %{}

    field :permissions, {:array, :string}, default: []

    has_many :user_configs, Central.Config.UserConfig
    has_many :reports_against, Central.Account.Report, foreign_key: :target_id
    has_many :reports_made, Central.Account.Report, foreign_key: :reporter_id
    has_many :reports_responded, Central.Account.Report, foreign_key: :responder_id

    # Extra user.ex relations go here

    belongs_to :admin_group, Central.Account.Group

    many_to_many :groups, Central.Account.Group,
      join_through: "account_group_memberships",
      join_keys: [user_id: :id, group_id: :id]

    timestamps()
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    if attrs["password"] == "" do
      user
      |> cast(attrs, [:name, :email, :icon, :colour, :permissions, :admin_group_id, :data])
      |> validate_required([:name, :email, :icon, :colour, :permissions])
    else
      user
      |> cast(attrs, [
        :name,
        :email,
        :password,
        :icon,
        :colour,
        :permissions,
        :admin_group_id,
        :data
      ])
      |> validate_required([:name, :email, :password, :icon, :colour, :permissions])
      |> put_password_hash()
    end
  end

  def changeset(struct, params, nil), do: changeset(struct, params)

  def changeset(struct, permissions, :permissions) do
    cast(struct, %{permissions: permissions}, [:permissions])
  end

  def changeset(user, attrs, :self_create) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> change_password(attrs)
  end

  def changeset(user, attrs, :limited) do
    user
    |> cast(attrs, [:name, :email, :icon, :colour])
    |> validate_required([:name, :email, :icon, :colour])
  end

  def changeset(user, attrs, :limited_with_data) do
    user
    |> cast(attrs, [:name, :email, :icon, :colour, :data])
    |> validate_required([:name, :email, :icon, :colour])
  end

  def changeset(user, attrs, :user_form) do
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
