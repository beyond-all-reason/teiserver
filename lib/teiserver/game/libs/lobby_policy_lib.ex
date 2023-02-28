defmodule Teiserver.Game.LobbyPolicyLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.{Game, Account}
  alias Teiserver.Game.{LobbyPolicy, LobbyPolicyOrganiserServer, LobbyPolicyBotServer}
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
      |> Parallel.map(&add_policy_from_db/1)
      |> Enum.count()

    Logger.info("pre_cache_policies, got #{policy_count} policies")
  end

  @doc """
  Given the name of the agent and the format for the name it will ensure the agent exists
  if it doesn't it will create it and then return the result
  """
  @spec get_or_make_agent_user(String.t(), LobbyPolicy.t()) :: T.user()
  def get_or_make_agent_user(base_name, lobby_policy) do
    formatted_name = lobby_policy.agent_name_format
      |> String.replace("{agent}", base_name)
      |> String.replace("{id}", "#{lobby_policy.id}")

    email_domain = Application.get_env(:central, Teiserver)[:bot_email_domain]
    email_addr = "#{base_name}_#{lobby_policy.id}_lobby_policy_bot@#{email_domain}"

    db_user = Account.get_user(nil, search: [
      email: email_addr
    ])

    case db_user do
      nil ->
        # Make account
        {:ok, user} = Account.create_user(%{
          name: formatted_name,
          email: email_addr,
          icon: "fa-solid fa-solar-system",
          colour: "#0000AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: Account.make_bot_password(),
          data: %{
            bot: true,
            moderator: true,
            verified: true,
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.update_user_stat(user.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag],
        })

        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.internal_group_id()
        })

        Account.recache_user(user.id)
        user

      _ ->
        # Ensure the username is correct (for if we changed the name format around)
        if db_user.name != formatted_name do
          Account.system_change_user_name(db_user.id, formatted_name)
        end

        db_user
    end
  end

  @spec start_lobby_policy_bot(T.lobby_policy_id(), Central.Account.User.t()) :: pid()
  def start_lobby_policy_bot(lobby_policy_id, user) do
    {:ok, consul_pid} =
      DynamicSupervisor.start_child(Teiserver.LobbyPolicySupervisor, {
        LobbyPolicyBotServer,
        name: "lobby_policy_bot_#{lobby_policy_id}_#{user.name}",
        data: %{
          userid: user.id,
          lobby_policy_id: lobby_policy_id,
        }
      })

    consul_pid
  end

  @spec add_policy_from_db(LobbyPolicy.t()) :: :ok | :exists | {:error, any}
  def add_policy_from_db(nil), do: {:error, "no policy"}
  def add_policy_from_db(%{enabled: false} = lobby_policy) do
    cast_lobby_organiser(lobby_policy.id, {:updated_policy, lobby_policy})
    :exists
  end
  def add_policy_from_db(%{enabled: true} = lobby_policy) do
    if get_lobby_organiser_pid(lobby_policy.id) do
      cast_lobby_organiser(lobby_policy.id, {:updated_policy, lobby_policy})
      :exists
    else
      result = DynamicSupervisor.start_child(Teiserver.LobbyPolicySupervisor, {
        LobbyPolicyOrganiserServer,
        name: "lobby_policy_supervisor_#{lobby_policy.id}",
        data: %{
          lobby_policy: lobby_policy
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

  @spec get_lobby_organiser_pid(T.lobby_policy_id()) :: pid() | nil
  def get_lobby_organiser_pid(lobby_policy_id) when is_integer(lobby_policy_id) do
    case Horde.Registry.lookup(Teiserver.LobbyPolicyRegistry, "LobbyPolicyOrganiserServer:#{lobby_policy_id}") do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @doc """
  GenServer.cast the message to the LobbyServer process for lobby_policy_id
  """
  @spec cast_lobby_organiser(T.lobby_policy_id(), any) :: :ok | nil
  def cast_lobby_organiser(lobby_policy_id, message) when is_integer(lobby_policy_id) do
    case get_lobby_organiser_pid(lobby_policy_id) do
      nil -> nil
      pid ->
        GenServer.cast(pid, message)
        :ok
    end
  end

  @doc """
  GenServer.call the message to the LobbyServer process for lobby_policy_id and return the result
  """
  @spec call_lobby_organiser(T.lobby_policy_id(), any) :: any | nil
  def call_lobby_organiser(lobby_policy_id, message) when is_integer(lobby_policy_id) do
    case get_lobby_organiser_pid(lobby_policy_id) do
      nil -> nil
      pid ->
        try do
          GenServer.call(pid, message)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end
end
