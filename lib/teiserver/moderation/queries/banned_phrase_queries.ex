defmodule Teiserver.Moderation.BannedPhraseQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.BannedPhrase

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec banned_phrases() :: t()
  def banned_phrases do
    from(banned_phrases in BannedPhrase, as: :banned_phrases)
  end

  @spec where_id(t(), BannedPhrase.id()) :: t()
  def where_id(query, id) do
    from banned_phrases in query,
      where: banned_phrases.id == ^id
  end

  @spec where_phrase_like(t(), nil | String.t()) :: t()
  def where_phrase_like(query, nil), do: query

  def where_phrase_like(query, phrase) do
    phrase = "%" <> phrase <> "%"

    from banned_phrases in query,
      where: ilike(banned_phrases.phrase, ^phrase)
  end

  @spec where_use_case(t(), nil | String.t()) :: t()
  def where_use_case(query, nil), do: query

  def where_use_case(query, use_case) do
    from banned_phrases in query,
      where: ^use_case in banned_phrases.use_cases
  end

  @spec order_by_inserted_at(t(), :asc | :desc) :: t()
  def order_by_inserted_at(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_phrases in query, order_by: [asc: banned_phrases.inserted_at])
    else
      from(banned_phrases in query, order_by: [desc: banned_phrases.inserted_at])
    end
  end

  @spec order_by_phrase(t(), :asc | :desc) :: t()
  def order_by_phrase(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_phrases in query, order_by: [asc: banned_phrases.phrase])
    else
      from(banned_phrases in query, order_by: [desc: banned_phrases.phrase])
    end
  end

  @spec order_by_from_string(t(), String.t()) :: t()
  def order_by_from_string(query, "Newest first"), do: order_by_inserted_at(query, :desc)
  def order_by_from_string(query, "Oldest first"), do: order_by_inserted_at(query, :asc)
  def order_by_from_string(query, "Alphabetical (A-Z)"), do: order_by_phrase(query, :asc)
  def order_by_from_string(query, "Alphabetical (Z-A)"), do: order_by_phrase(query, :desc)
end
