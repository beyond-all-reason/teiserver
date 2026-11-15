defmodule Teiserver.Moderation.BannedPhrase do
  @moduledoc """
  A phrase banned in the game which could warrant an action if detected.

  All tests are checked as case insensitive.

  Types:
    raw - if the phrase is present in the message it will trigger
    fuzzy - uses * as wildcards for as many characters as needed
            executed as a regex
    regex - a regex, if the pattern matches it will trigger

  Score threshold is not currently used but is intended to be used
  in the future for partial match types.
  """
  alias Ecto.Changeset
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase

  use TeiserverWeb, :schema

  @type search_type :: :raw | :fuzzy | :regex

  @type id :: non_neg_integer()

  typed_schema "banned_phrases" do
    field :phrase, :string
    field :score_threshold, :integer
    field :type, Ecto.Enum, values: [:raw, :fuzzy, :regex]

    field :use_cases, {:array, :string}, default: []

    # The version of the phrase after being loaded into memory,
    # for example a regex would be compiled as a regex so it can be processed
    field :loaded_phrase, :any, virtual: true

    timestamps()
  end

  def types, do: [:raw, :fuzzy, :regex]
  def use_cases, do: ["username", "chat", "lobby name"]

  @doc false
  def changeset(banned_phrase, attrs) do
    # We purposefully allow length 0 use_cases
    banned_phrase
    |> cast(attrs, [:phrase, :score_threshold, :type, :use_cases])
    |> validate_required([:phrase, :score_threshold, :type, :use_cases])
    |> unique_constraint([:phrase])
    |> validate_phrase()
  end

  defp validate_phrase(%Changeset{} = changeset) do
    case get_field(changeset, :type) do
      :fuzzy -> validate_fuzzy_phrase(changeset)
      :regex -> validate_regex_phrase(changeset)
      _any_other -> changeset
    end
  end

  defp validate_fuzzy_phrase(%Changeset{} = changeset) do
    phrase = get_field(changeset, :phrase) || ""

    pattern = phrase |> Regex.escape() |> String.replace("\\*", ".*")

    if String.contains?(phrase, "*") do
      validate_pattern(changeset, pattern)
    else
      add_error(
        changeset,
        :phrase,
        "Fuzzy phrase needs to contain at least one wildcard (*), did you mean to use the 'raw' type?"
      )
    end
  end

  defp validate_regex_phrase(%Changeset{} = changeset) do
    pattern = get_field(changeset, :phrase)
    validate_pattern(changeset, pattern)
  end

  defp validate_pattern(%Changeset{} = changeset, pattern) do
    case Regex.compile(pattern) do
      {:ok, _regex} ->
        changeset

      {:error, {error_chars, pos}} ->
        error_str = List.to_string(error_chars)
        add_error(changeset, :phrase, "Invalid regex - #{error_str}, pos: #{pos}")
    end
  end

  @doc """
  Given a BannedPhrase loaded from the database cache the loaded_phrase
  field.
  """
  @spec load_phrase(BannedPhrase.t()) :: BannedPhrase.t()
  def load_phrase(%BannedPhrase{type: :regex, phrase: phrase} = banned_phrase) do
    {:ok, compiled_phrase} = Regex.compile(phrase, "i")
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  def load_phrase(%BannedPhrase{type: :fuzzy, phrase: phrase} = banned_phrase) do
    pattern =
      phrase
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    {:ok, compiled_phrase} = Regex.compile(pattern, "i")
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  # Raw phrases are stored as a list of lowercase parts (a phrase can contain
  # several comma separated alternatives) so no work is needed at match time
  def load_phrase(%BannedPhrase{phrase: phrase} = banned_phrase) do
    parts = phrase |> String.downcase() |> String.split(",")
    %BannedPhrase{banned_phrase | loaded_phrase: parts}
  end

  @doc """
  Runs through a filtered list of banned phrases and says if any match
  """
  @spec message_is_banned?(String.t(), String.t() | nil, [search_type()]) :: boolean()
  def message_is_banned?(
        message,
        use_case \\ nil,
        types \\ [:raw, :fuzzy, :regex]
      ) do
    found_phrase =
      :telemetry.span(
        [:teiserver, :moderation, :message_is_banned?],
        %{use_case: use_case},
        fn ->
          # Raw phrases are case insensitive, downcase the message once rather
          # than once per phrase
          lowered_message = String.downcase(message)

          found_phrase =
            Moderation.list_banned_phrases_cache(use_case)
            |> Enum.find(fn %BannedPhrase{type: type} = banned_phrase ->
              Enum.member?(types, type) and
                phrase_match?(banned_phrase, message, lowered_message)
            end)

          {found_phrase, %{matched: found_phrase != nil}}
        end
      )

    # Track which phrases are being triggered
    if found_phrase do
      :telemetry.execute([:teiserver, :moderation, :message_is_banned], %{}, %{
        found_phrase_id: found_phrase.id
      })
    end

    # If we found anything at all then the message is banned in this use case
    not is_nil(found_phrase)
  end

  @doc """
  Given a banned phrase and a message, does the message
  trigger the banned phrase?
  """
  @spec phrase_match?(BannedPhrase.t(), String.t()) :: boolean()
  def phrase_match?(%BannedPhrase{} = banned_phrase, message) do
    phrase_match?(banned_phrase, message, String.downcase(message))
  end

  # Same as phrase_match?/2 but takes the already downcased message so callers
  # checking many phrases against one message only downcase it once
  @spec phrase_match?(BannedPhrase.t(), String.t(), String.t()) :: boolean()
  defp phrase_match?(
         %BannedPhrase{type: :raw, loaded_phrase: parts},
         _message,
         lowered_message
       ) do
    String.contains?(lowered_message, parts)
  end

  defp phrase_match?(
         %BannedPhrase{type: type, loaded_phrase: loaded_phrase},
         message,
         _lowered_message
       )
       when type in [:regex, :fuzzy] do
    Regex.match?(loaded_phrase, message)
  end
end
