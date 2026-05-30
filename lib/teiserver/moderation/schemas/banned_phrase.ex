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

  @type severity :: :low | :medium | :high
  @type search_type :: :raw | :fuzzy | :regex

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

  def load_phrase(%BannedPhrase{phrase: phrase} = banned_phrase) do
    %BannedPhrase{banned_phrase | loaded_phrase: String.downcase(phrase)}
  end

  @doc """
  Runs through a filtered list of banned phrases and returns the highest severity
  matched by the message.
  """
  @spec message_severity(String.t(), severity(), [search_type()]) :: nil | BannedPhrase.severity()
  def message_severity(message, min_severity \\ :high, types \\ [:raw, :fuzzy, :regex]) do
    found_phrase =
      Moderation.list_banned_phrases_cache()
      |> Enum.filter(fn %BannedPhrase{type: type, severity: severity} ->
        severity_is_at_least(severity, min_severity) and Enum.member?(types, type)
      end)
      |> Enum.find(fn %BannedPhrase{type: type, severity: severity} = banned_phrase ->
        severity_is_at_least(severity, min_severity) and
          Enum.member?(types, type) and
          phrase_match?(banned_phrase, message)
      end)

    if found_phrase do
      found_phrase.severity
    end
  end

  defp severity_is_at_least(severity_tested, severity_minimum) do
    case severity_minimum do
      :low -> true
      :medium -> Enum.member?([:medium, :high], severity_tested)
      :high -> :high == severity_tested
    end
  end

  @doc """
  Given a banned phrase and a message, does the message
  trigger the banned phrase?
  """
  @spec phrase_match?(BannedPhrase.t(), String.t()) :: boolean()
  def phrase_match?(%BannedPhrase{type: :raw, loaded_phrase: loaded_phrase}, message) do
    message
    |> String.downcase()
    |> String.contains?(loaded_phrase)
  end

  def phrase_match?(%BannedPhrase{type: type, loaded_phrase: loaded_phrase}, message)
      when type in [:regex, :fuzzy] do
    Regex.match?(loaded_phrase, message)
  end
end
