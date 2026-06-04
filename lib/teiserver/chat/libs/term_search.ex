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
  Builds a dynamic WHERE expression matching a message's `content` against the
  given term, honouring the `:case_sensitive` and `:whole_word` options.

  Returns `nil` when the term is blank, meaning no filtering should be applied.
  The dynamic references the first query binding positionally, so it works with
  any of the message schemas.
  """
  @spec content_filter(String.t() | nil, keyword()) :: Ecto.Query.dynamic_expr() | nil
  def content_filter(term, opts \\ [])
  def content_filter(term, _opts) when term in [nil, ""], do: nil

  def content_filter(term, opts) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)
    whole_word = Keyword.get(opts, :whole_word, false)

    if whole_word do
      # \y is a word boundary in PostgreSQL POSIX regex (equivalent to \b in PCRE)
      pattern = "\\y" <> regex_term(term) <> "\\y"

      if case_sensitive do
        dynamic([m], fragment("? ~ ?", m.content, ^pattern))
      else
        dynamic([m], fragment("? ~* ?", m.content, ^pattern))
      end
    else
      like_term = "%" <> String.replace(term, "*", "%") <> "%"

      if case_sensitive do
        dynamic([m], like(m.content, ^like_term))
      else
        dynamic([m], ilike(m.content, ^like_term))
      end
    end
  end

  defp regex_term(term) do
    term
    |> Regex.escape()
    |> String.replace("\\*", ".*")
  end
end
