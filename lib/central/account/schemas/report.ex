defmodule Central.Account.Report do
  @moduledoc false
  use CentralWeb, :schema

  schema "account_reports" do
    field :location, :string
    field :location_id, :integer

    field :reason, :string

    belongs_to :reporter, Central.Account.User
    belongs_to :target, Central.Account.User

    field :response_text, :string
    field :response_action, :string
    field :expires, :naive_datetime
    belongs_to :responder, Central.Account.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:location, :reason, :response_text, :response_action])
      |> parse_humantimes([:expires])

    struct
    |> cast(params, [
      :location,
      :location_id,
      :reason,
      :reporter_id,
      :target_id,
      :response_text,
      :response_action,
      :responder_id,
      :expires
    ])
    |> validate_required([:reporter_id, :target_id])
  end

  def create_changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:location, :reason])

    struct
    |> cast(params, [:location, :location_id, :reason, :reporter_id, :target_id])
    |> validate_required([:reporter_id, :target_id])
  end

  def respond_changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:response_text, :response_action])

    struct
    |> cast(params, [:response_text, :response_action, :responder_id, :expires])
    |> validate_required([:response_text, :response_action, :responder_id])
  end

  def authorize(:edit, conn, _), do: allow?(conn, "admin.dev")
  def authorize(:update, conn, _), do: allow?(conn, "admin.dev")
  def authorize(_, conn, _), do: allow?(conn, "admin.report")
end
