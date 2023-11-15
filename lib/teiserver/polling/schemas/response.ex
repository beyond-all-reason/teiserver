defmodule Teiserver.Polling.Response do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "polling_questions" do
    belongs_to :survey, Teiserver.Polling.Survey
    belongs_to :responder, Teiserver.Account.User

    field :is_completed, :boolean, default: false
    field :completed_at, :utc_datetime
    field :current_page, :integer

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(survey_id responder_id completed completed_at current_page)a)
    |> validate_required(~w(survey_id responder_id)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Polling")
end
