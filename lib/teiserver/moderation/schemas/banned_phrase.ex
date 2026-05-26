defmodule Teiserver.Moderation.BannedPhrase do
  @moduledoc """
  A phrase banned in the game which would warrant an action if detected.
  """
  use TeiserverWeb, :schema

  typed_schema "banned_phrases" do
    field :phrase, :string
    field :score_threshold, :integer
    field :type, Ecto.Enum, values: [:raw, :fuzzy, :regex]
    field :severity, Ecto.Enum, values: [:low, :medium, :high]

    # The version of the phrase after being loaded into memory,
    # for example a regex would be compiled as a regex so it can be processed
    field :loaded_phrase, :any, virtual: true

    timestamps()
  end

  def types, do: [:raw, :fuzzy, :regex]
  def severities, do: [:low, :medium, :high]

  @doc false
  def changeset(banned_phrase, attrs) do
    banned_phrase
    |> cast(attrs, [:phrase, :score_threshold, :type, :severity])
    |> validate_required([:phrase, :score_threshold, :type, :severity])
    |> unique_constraint([:phrase])
  end
end
