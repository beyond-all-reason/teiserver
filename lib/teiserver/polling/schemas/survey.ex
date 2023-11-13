defmodule Teiserver.Polling.Survey do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "polling_surveys" do
    field :name, :string
    belongs_to :author, Teiserver.Account.User

    field :colour, :string
    field :icon, :string

    field :opens_at, :utc_datetime
    field :closes_at, :utc_datetime
    field :closed, :boolean

    # Who can answer this survey? If nil then anybody can
    field :user_permission, :string

    # Who can view the results of this survey? If nil then only the author and admins can
    field :results_permission, :string

    # Who can edit this survey? If nil then only the author and the Admin usergroup can
    field :edit_permission, :string

    has_many :questions, Teiserver.Polling.Question
    has_many :responses, Teiserver.Polling.Response

    # Optionally we may want to later use a many to many for the answers
    # I think this is the correct syntax but check the join_keys
    # many_to_many :answer_texts, Teiserver.Polling.AnswerString,
    #   join_through: "polling_responses",
    #   join_keys: [survey_id: :id, answer_text_id: :id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name colour icon user_permission results_permission edit_permission)a)

    struct
    |> cast(params, ~w(name author_id colour icon opens_at closes_at closed user_permission results_permission edit_permission)a)
    |> validate_required(~w(name author_id colour icon)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Contributor")
end
