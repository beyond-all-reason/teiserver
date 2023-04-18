defmodule Teiserver.Communication.TextCallbackLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Config
  alias Teiserver.{Game, Account}
  alias Teiserver.Communication.{TextCallback, TextCallbackOrganiserServer, TextCallbackBotServer}
  alias Teiserver.Data.Types, as: T
  require Logger

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-webhook"

  @spec colours :: atom
  def colours, do: :success2

  @spec make_favourite(Queue.t()) :: Map.t()
  def make_favourite(text_callback) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: text_callback.id,
      item_type: "text_callback",
      item_colour: text_callback.colour,
      item_icon: text_callback.icon,
      item_label: "#{text_callback.name}",
      url: "/teiserver/admin/text_callbacks/#{text_callback.id}"
    }
  end

  # Queries
  @spec query_text_callbacks() :: Ecto.Query.t()
  def query_text_callbacks do
    from(text_callbacks in TextCallback)
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
    from text_callbacks in query,
      where: text_callbacks.id == ^id
  end

  def _search(query, :name, name) do
    from text_callbacks in query,
      where: text_callbacks.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from text_callbacks in query,
      where: text_callbacks.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from text_callbacks in query,
      where: ilike(text_callbacks.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from text_callbacks in query,
      order_by: [asc: text_callbacks.name]
  end

  def order_by(query, "Name (Z-A)") do
    from text_callbacks in query,
      order_by: [desc: text_callbacks.name]
  end

  def order_by(query, "Newest first") do
    from text_callbacks in query,
      order_by: [desc: text_callbacks.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from text_callbacks in query,
      order_by: [asc: text_callbacks.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from text_callbacks in query,
  #     left_join: things in assoc(text_callbacks, :things),
  #     preload: [things: things]
  # end

  @spec pre_cache_policies :: :ok
  def pre_cache_policies() do
    policy_count =
      Game.list_text_callbacks()
      |> Parallel.map(&add_policy_from_db/1)
      |> Enum.count()

    Logger.info("pre_cache_policies, got #{policy_count} policies")
  end

  @doc """
  Given the name of the agent and the format for the name it will ensure the agent exists
  if it doesn't it will create it and then return the result
  """
  @spec get_or_make_agent_user(String.t(), TextCallback.t()) :: T.user()
  def get_or_make_agent_user(base_name, text_callback) do
    formatted_name =
      text_callback.agent_name_format
      |> String.replace("{agent}", base_name)
      |> String.replace("{id}", "#{text_callback.id}")

    email_domain = Application.get_env(:central, Teiserver)[:bot_email_domain]
    email_addr = "#{base_name}_#{text_callback.id}_text_callback_bot@#{email_domain}"

    db_user =
      Account.get_user(nil,
        search: [
          email: email_addr
        ]
      )

    user =
      case db_user do
        nil ->
          # Make account
          {:ok, user} =
            Account.create_user(%{
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

    Account.update_user_stat(user.id, %{
      country_override: Config.get_site_config_cache("bots.Flag")
    })

    user
  end

  @spec start_text_callback_bot(TextCallback.t(), String.t(), Central.Account.User.t()) :: pid()
  def start_text_callback_bot(text_callback, base_name, user) do
    {:ok, policy_bot_pid} =
      DynamicSupervisor.start_child(Teiserver.TextCallbackSupervisor, {
        TextCallbackBotServer,
        name: "text_callback_bot_#{text_callback.id}_#{user.name}",
        data: %{
          userid: user.id,
          base_name: base_name,
          text_callback: text_callback
        }
      })

    policy_bot_pid
  end

  @spec add_policy_from_db(TextCallback.t()) :: :ok | :exists | {:error, any}
  def add_policy_from_db(nil), do: {:error, "no policy"}

  def add_policy_from_db(%{enabled: false} = text_callback) do
    cast_lobby_organiser(text_callback.id, {:updated_policy, text_callback})
    cache_updated_text_callback(text_callback)
    :exists
  end

  def add_policy_from_db(%{enabled: true} = text_callback) do
    cache_updated_text_callback(text_callback)

    cond do
      Application.get_env(:central, Teiserver)[:enable_managed_lobbies] == false ->
        :disabled

      get_lobby_organiser_pid(text_callback.id) != nil ->
        cast_lobby_organiser(text_callback.id, {:updated_policy, text_callback})
        :exists

      true ->
        result =
          DynamicSupervisor.start_child(Teiserver.TextCallbackSupervisor, {
            TextCallbackOrganiserServer,
            name: "text_callback_supervisor_#{text_callback.id}",
            data: %{
              text_callback: text_callback
            }
          })

        case result do
          {:error, err} ->
            Logger.error(
              "Error starting TextCallbackSupervisor: #{__ENV__.file}:#{__ENV__.line}\n#{inspect(err)}"
            )

            {:error, err}

          {:ok, _pid} ->
            :ok
        end
    end
  end

  defp cache_updated_text_callback(text_callback) do
    Central.cache_update(:lists, :text_callbacks, fn value ->
      new_value =
        [text_callback.id | value]
        |> Enum.uniq()

      {:ok, new_value}
    end)

    Central.cache_put(:text_callbacks_cache, text_callback.id, text_callback)
  end

  @spec get_lobby_organiser_pid(T.text_callback_id()) :: pid() | nil
  def get_lobby_organiser_pid(text_callback_id) when is_integer(text_callback_id) do
    case Horde.Registry.lookup(
           Teiserver.TextCallbackRegistry,
           "TextCallbackOrganiserServer:#{text_callback_id}"
         ) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec list_cached_text_callbacks() :: list()
  def list_cached_text_callbacks() do
    Central.cache_get(:lists, :text_callbacks)
    |> Enum.map(fn id ->
      get_cached_text_callback(id)
    end)
  end

  @spec get_cached_text_callback(non_neg_integer()) :: TextCallback.t()
  def get_cached_text_callback(id) do
    Central.cache_get(:text_callbacks_cache, id)
  end

  @doc """
  GenServer.cast the message to the LobbyServer process for text_callback_id
  """
  @spec cast_lobby_organiser(T.text_callback_id(), any) :: :ok | nil
  def cast_lobby_organiser(text_callback_id, message) when is_integer(text_callback_id) do
    case get_lobby_organiser_pid(text_callback_id) do
      nil ->
        nil

      pid ->
        GenServer.cast(pid, message)
        :ok
    end
  end

  @doc """
  GenServer.call the message to the LobbyServer process for text_callback_id and return the result
  """
  @spec call_lobby_organiser(T.text_callback_id(), any) :: any | nil
  def call_lobby_organiser(text_callback_id, message) when is_integer(text_callback_id) do
    case get_lobby_organiser_pid(text_callback_id) do
      nil ->
        nil

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
