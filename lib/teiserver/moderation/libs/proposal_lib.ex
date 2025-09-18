defmodule Teiserver.Moderation.ProposalLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Proposal

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-booth-curtain"

  @spec colour :: atom
  def colour, do: :success

  @spec make_favourite(map()) :: map()
  def make_favourite(proposal) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: proposal.id,
      item_type: "teiserver_moderation_proposal",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{proposal.target.name}",
      url: "/moderation/proposals/#{proposal.id}"
    }
  end

  # Queries
  @spec query_proposals() :: Ecto.Query.t()
  def query_proposals do
    from(proposals in Proposal)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from proposals in query,
      where: proposals.id == ^id
  end

  def _search(query, :target_id, target_id) do
    from actions in query,
      where: actions.target_id == ^target_id
  end

  def _search(query, :target_id_in, id_list) do
    from actions in query,
      where: actions.target_id in ^id_list
  end

  def _search(query, :proposer_id, proposer_id) do
    from actions in query,
      where: actions.proposer_id == ^proposer_id
  end

  def _search(query, :proposer_id_in, id_list) do
    from actions in query,
      where: actions.proposer_id in ^id_list
  end

  def _search(query, :id_list, id_list) do
    from proposals in query,
      where: proposals.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from proposals in query,
      where: ilike(proposals.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from proposals in query,
      order_by: [asc: proposals.name]
  end

  def order_by(query, "Name (Z-A)") do
    from proposals in query,
      order_by: [desc: proposals.name]
  end

  def order_by(query, "Newest first") do
    from proposals in query,
      order_by: [desc: proposals.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from proposals in query,
      order_by: [asc: proposals.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :target in preloads, do: _preload_target(query), else: query
    query = if :proposer in preloads, do: _preload_proposer(query), else: query
    query = if :concluder in preloads, do: _preload_concluder(query), else: query
    query = if :votes in preloads, do: _preload_votes(query), else: query
    query
  end

  @spec _preload_target(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_target(query) do
    from proposals in query,
      left_join: targets in assoc(proposals, :target),
      preload: [target: targets]
  end

  @spec _preload_proposer(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_proposer(query) do
    from proposals in query,
      left_join: proposers in assoc(proposals, :proposer),
      preload: [proposer: proposers]
  end

  @spec _preload_concluder(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_concluder(query) do
    from proposals in query,
      left_join: concluders in assoc(proposals, :concluder),
      preload: [concluder: concluders]
  end

  @spec _preload_votes(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_votes(query) do
    from proposals in query,
      left_join: votes in assoc(proposals, :votes),
      left_join: users in assoc(votes, :user),
      preload: [votes: {votes, user: users}]
  end
end
