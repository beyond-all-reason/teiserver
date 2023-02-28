defmodule Teiserver.Game.LobbyPolicyLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.{Game, Account}
  alias Teiserver.Game.{LobbyPolicy, LobbyPolicyOrganiserServer}
  alias Teiserver.Data.Types, as: T
  require Logger

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-box"

  @spec colours :: atom
  def colours, do: :success2

  @spec make_favourite(Queue.t()) :: Map.t()
  def make_favourite(lobby_policy) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: lobby_policy.id,
      item_type: "lobby_policy",
      item_colour: lobby_policy.colour,
      item_icon: lobby_policy.icon,
      item_label: "#{lobby_policy.name}",
      url: "/teiserver/admin/lobby_policies/#{lobby_policy.id}"
    }
  end

  # Queries
  @spec query_lobby_policies() :: Ecto.Query.t()
  def query_lobby_policies do
    from(lobby_policies in LobbyPolicy)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from lobby_policies in query,
      where: lobby_policies.id == ^id
  end

  def _search(query, :name, name) do
    from lobby_policies in query,
      where: lobby_policies.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from lobby_policies in query,
      where: lobby_policies.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from lobby_policies in query,
      where: ilike(lobby_policies.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from lobby_policies in query,
      order_by: [asc: lobby_policies.name]
  end

  def order_by(query, "Name (Z-A)") do
    from lobby_policies in query,
      order_by: [desc: lobby_policies.name]
  end

  def order_by(query, "Newest first") do
    from lobby_policies in query,
      order_by: [desc: lobby_policies.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from lobby_policies in query,
      order_by: [asc: lobby_policies.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from lobby_policies in query,
  #     left_join: things in assoc(lobby_policies, :things),
  #     preload: [things: things]
  # end

  @spec pre_cache_policies :: :ok
  def pre_cache_policies() do
    policy_count =
      Game.list_lobby_policies
      |> Parallel.map(&add_policy/1)
      |> Enum.count()

    Logger.info("pre_cache_policies, got #{policy_count} policies")
  end

  @doc """
  Given the name of the agent and the format for the name it will ensure the agent exists
  if it doesn't it will create it and then return the result
  """
  @spec get_or_make_agent_user(String.t(), String.t(), LobbyPolicy.t()) :: T.user()
  def get_or_make_agent_user(base_name, format, lobby_policy) do
    formatted_name = format
      |> String.replace("{agent}", base_name)

    email_domain = Application.get_env(:central, Teiserver)[:bot_email_domain]
    email_addr = "#{base_name}@#{email_domain}"

    user = Account.get_user(nil, search: [
      email: email_addr
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "Coordinator",
          email: "coordinator@teiserver",
          icon: "fa-solid fa-sitemap",
          colour: "#AA00AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: Account.make_bot_password(),
          data: %{
            bot: true,
            moderator: true,
            verified: true,
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag],
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })

        User.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @spec add_policy(LobbyPolicy.t()) :: :ok | {:error, any}
  def add_policy(nil), do: {:error, "no policy"}
  def add_policy(policy) do
    result = DynamicSupervisor.start_child(Teiserver.LobbyPolicySupervisor, {
      LobbyPolicyOrganiserServer,
      %{
        lobby_policy: policy
      }
    })

    case result do
      {:error, err} ->
        Logger.error("Error starting LobbyPolicySupervisor: #{__ENV__.file}:#{__ENV__.line}\n#{inspect err}")
        {:error, err}
      {:ok, _pid} ->
        :ok
    end
  end
end
