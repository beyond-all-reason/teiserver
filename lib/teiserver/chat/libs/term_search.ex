defmodule Teiserver.Chat.TermSearch do
  @moduledoc """
  Shared helper for building the `:term` content filter used by the chat
  message query libs (lobby/room/party/direct).

  Supports two options:
    * `:case_sensitive` (default `false`) - when `true`, matching respects
      letter casing.
    * `:whole_word` (default `false`) - when `true`, the term only matches
      when it appears as a standalone word (bounded by word boundaries),
      rather than as part of a larger word.

  As with the existing behaviour, `*` in the term acts as a wildcard for any
  number of characters.
  """

  import Ecto.Query

  @doc """
  Filters `query` by matching the `content` field against `term`, honouring
  the `:case_sensitive` and `:whole_word` options.

  Returns the query unchanged when `term` is blank.
  The binding name `m` refers to the first query binding positionally, so it
  works with any of the message schemas.
  """
  @spec content_filter(Ecto.Query.t(), String.t() | nil, keyword()) :: Ecto.Query.t()
  def content_filter(query, term, opts \\ [])
  def content_filter(query, term, _opts) when term in [nil, ""], do: query

  def content_filter(query, term, opts) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)
    whole_word = Keyword.get(opts, :whole_word, false)

    if whole_word do
      # \y is a word boundary in PostgreSQL POSIX regex (equivalent to \b in PCRE)
      pattern = "\\y" <> regex_term(term) <> "\\y"

      if case_sensitive do
        where(query, [m], fragment("? ~ ?", m.content, ^pattern))
      else
        where(query, [m], fragment("? ~* ?", m.content, ^pattern))
      end
    else
      like_term = "%" <> String.replace(term, "*", "%") <> "%"

      if case_sensitive do
        where(query, [m], like(m.content, ^like_term))
      else
        where(query, [m], ilike(m.content, ^like_term))
      end
    end
  end

  defp regex_term(term) do
    term
    |> Regex.escape()
    |> String.replace("\\*", ".*")
  end
end
