defmodule Teiserver.Moderation.BannedPhrase do
  @moduledoc """
  A phrase banned in the game which could warrant an action if detected.

  Matching is case sensitive by default; set `case_sensitive: false` for a
  case insensitive match. Set `whole_word: true` to only match the phrase
  when it appears as a standalone word (bounded by word boundaries).

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
    field :case_sensitive, :boolean, default: true
    field :whole_word, :boolean, default: false

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
    |> cast(attrs, [:phrase, :score_threshold, :type, :severity, :case_sensitive, :whole_word])
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
    {:ok, compiled_phrase} = compile_pattern(phrase, banned_phrase)
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  def load_phrase(%BannedPhrase{type: :fuzzy, phrase: phrase} = banned_phrase) do
    pattern =
      phrase
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    {:ok, compiled_phrase} = compile_pattern(pattern, banned_phrase)
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  # raw with no matching options stays a plain string for the fast
  # String.contains? path.
  def load_phrase(
        %BannedPhrase{type: :raw, phrase: phrase, whole_word: whole_word} = banned_phrase
      )
      when whole_word in [false, nil] do
    if case_sensitive?(banned_phrase) do
      %BannedPhrase{banned_phrase | loaded_phrase: phrase}
    else
      {:ok, compiled_phrase} = compile_pattern(Regex.escape(phrase), banned_phrase)
      %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
    end
  end

  # raw with whole_word is promoted to a regex.
  def load_phrase(%BannedPhrase{type: :raw, phrase: phrase} = banned_phrase) do
    {:ok, compiled_phrase} = compile_pattern(Regex.escape(phrase), banned_phrase)
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  # Compiles the (already escaped/translated) pattern into a Regex, applying
  # the whole_word and case_sensitive options of the banned phrase.
  defp compile_pattern(pattern, %BannedPhrase{} = banned_phrase) do
    pattern
    |> maybe_wrap_whole_word(banned_phrase)
    |> Regex.compile(regex_opts(banned_phrase))
  end

  defp maybe_wrap_whole_word(pattern, %BannedPhrase{whole_word: true}), do: "\\b#{pattern}\\b"
  defp maybe_wrap_whole_word(pattern, %BannedPhrase{}), do: pattern

  defp regex_opts(%BannedPhrase{} = banned_phrase) do
    if case_sensitive?(banned_phrase), do: "", else: "i"
  end

  # Defaults to case sensitive when the field is nil (e.g. a struct built
  # before the column existed).
  defp case_sensitive?(%BannedPhrase{case_sensitive: false}), do: false
  defp case_sensitive?(%BannedPhrase{}), do: true

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
  def phrase_match?(%BannedPhrase{loaded_phrase: %Regex{} = loaded_phrase}, message) do
    Regex.match?(loaded_phrase, message)
  end

  def phrase_match?(%BannedPhrase{type: :raw, loaded_phrase: loaded_phrase}, message) do
    String.contains?(message, loaded_phrase)
  end
end
