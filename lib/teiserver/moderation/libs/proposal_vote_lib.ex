defmodule Teiserver.Moderation.ProposalVoteLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.ProposalVote

  # Queries
  @spec query_proposal_votes() :: Ecto.Query.t()
  def query_proposal_votes do
    from(proposal_votes in ProposalVote)
  end

  @spec search(Ecto.Query.t(), keyword() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from proposal_votes in query,
      where: proposal_votes.user_id == ^user_id
  end

  def _search(query, :proposal_id, proposal_id) do
    from proposal_votes in query,
      where: proposal_votes.proposal_id == ^proposal_id
  end
end
