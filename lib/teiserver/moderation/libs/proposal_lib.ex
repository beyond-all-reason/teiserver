defmodule Teiserver.Moderation.ProposalLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Proposal

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-booth-curtain"

  @spec colour :: atom
  def colour, do: :success

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(proposal) do
    %{
      type_colour: colour(),
      type_icon: icon(),

      item_id: proposal.id,
      item_type: "teiserver_moderation_proposal",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{proposal.name}",

      url: "/moderation/proposals/#{proposal.id}"
    }
  end

  # Queries
  @spec query_proposals() :: Ecto.Query.t
  def query_proposals do
    from proposals in Proposal
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from proposals in query,
      where: proposals.id == ^id
  end

  def _search(query, :name, name) do
    from proposals in query,
      where: proposals.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from proposals in query,
      where: proposals.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from proposals in query,
      where: (
            ilike(proposals.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
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

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from proposals in query,
  #     left_join: things in assoc(proposals, :things),
  #     preload: [things: things]
  # end
end
