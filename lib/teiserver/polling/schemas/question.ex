defmodule Teiserver.Polling.Question do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "polling_questions" do
    field :label, :string
    field :description, :string
    field :question_type, :string

    field :options, :map, default: %{}
    field :ordering, :integer
    field :page, :integer

    belongs_to :survey, Teiserver.Polling.Survey

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(label description question_type)a)

    struct
    |> cast(params, ~w(label description question_type options ordering page survey_id)a)
    |> validate_required(~w(label description question_type options ordering page survey_id)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Polling")
end
