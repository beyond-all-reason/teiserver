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

  @spec order_by_severity(t(), :asc | :desc) :: t()
  def order_by_severity(query, direction \\ :asc) do
    if direction == :asc do
      from(banned_phrases in query, order_by: [asc: banned_phrases.severity])
    else
      from(banned_phrases in query, order_by: [desc: banned_phrases.severity])
    end
  end
end
