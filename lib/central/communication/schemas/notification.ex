defmodule Central.Communication.Notification do
  use CentralWeb, :schema

  schema "communication_notifications" do
    field :title, :string
    field :body, :string
    field :icon, :string
    field :colour, :string
    field :redirect, :string

    field :read, :boolean, default: false
    field :expired, :boolean, default: false
    field :expires, :utc_datetime

    belongs_to :user, Central.Account.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :title, :body, :icon, :colour, :redirect, :read, :expires])
    |> validate_required([:user_id, :title, :body, :read, :expires])
  end

  def new_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :title, :body, :icon, :colour, :redirect, :expires])
    |> validate_required([:user_id, :title, :body, :expires])
  end
end
