defmodule Teiserver.Communication.DiscordChannelLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Account
  alias Teiserver.Communication.{DiscordChannel, DiscordChannelQueries}
  alias Teiserver.Data.Types, as: T

  @spec special_channels() :: [String.t()]
  def special_channels do
    [
      "Announcements",
      "Dev updates",
      "Main chat",
      "Looking for players",
      "New player chat",
      "Public moderation log",
      "Overwatch reports",
      "Moderation reports",
      "Server updates",
      "Error updates",
      "Github updates",
      "Dev channel"
    ]
  end

  @spec counter_channels() :: [String.t()]
  def counter_channels do
    [
      "Lobbies (counter)",
      "Matches (counter)",
      "Clients (counter)",
      "Players (counter)"
    ]
  end

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-brands fa-discord"

  @spec colours :: atom
  def colours, do: :primary

  @doc """
  Returns the list of discord_channels.

  ## Examples

      iex> list_discord_channels()
      [%DiscordChannel{}, ...]

  """
  @spec list_discord_channels(list) :: list
  def list_discord_channels(args \\ []) do
    args
    |> DiscordChannelQueries.query_discord_channels()
    |> Repo.all()
  end

  @doc """
  Gets a single discord_channel.

  Raises `Ecto.NoResultsError` if the DiscordChannel does not exist.

  ## Examples

      iex> get_discord_channel!(123)
      %DiscordChannel{}

      iex> get_discord_channel!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_discord_channel!(non_neg_integer()) :: DiscordChannel.t()
  def get_discord_channel!(discord_channel_id) do
    [id: discord_channel_id]
    |> DiscordChannelQueries.query_discord_channels()
    |> Repo.one!()
  end

  @spec get_discord_channel(non_neg_integer() | String.t()) :: DiscordChannel.t() | nil
  def get_discord_channel(discord_channel_id) when is_integer(discord_channel_id) do
    [id: discord_channel_id]
    |> DiscordChannelQueries.query_discord_channels()
    |> Repo.one()
  end

  def get_discord_channel(discord_channel_name) do
    Teiserver.cache_get(:discord_channel_cache, discord_channel_name)
  end

  @doc """
  Creates a discord_channel.

  ## Examples

      iex> create_discord_channel(%{field: value})
      {:ok, %DiscordChannel{}}

      iex> create_discord_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_discord_channel(attrs \\ %{}) do
    %DiscordChannel{}
    |> DiscordChannel.changeset(attrs)
    |> Repo.insert()
    |> cache_channel()
  end

  @doc """
  Updates a discord_channel.

  ## Examples

      iex> update_discord_channel(discord_channel, %{field: new_value})
      {:ok, %DiscordChannel{}}

      iex> update_discord_channel(discord_channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_discord_channel(%DiscordChannel{} = discord_channel, attrs) do
    discord_channel
    |> DiscordChannel.changeset(attrs)
    |> Repo.update()
    |> cache_channel()
  end

  @doc """
  Deletes a discord_channel.

  ## Examples

      iex> delete_discord_channel(discord_channel)
      {:ok, %DiscordChannel{}}

      iex> delete_discord_channel(discord_channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_discord_channel(%DiscordChannel{} = discord_channel) do
    Teiserver.cache_delete(:discord_channel_cache, discord_channel.name)
    Repo.delete(discord_channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking discord_channel changes.

  ## Examples

      iex> change_discord_channel(discord_channel)
      %Ecto.Changeset{data: %DiscordChannel{}}

  """
  def change_discord_channel(%DiscordChannel{} = discord_channel, attrs \\ %{}) do
    DiscordChannel.changeset(discord_channel, attrs)
  end

  defp cache_channel({:error, channel}), do: {:error, channel}

  defp cache_channel({:ok, %DiscordChannel{} = channel}) do
    Teiserver.cache_put(:discord_channel_cache, channel.name, channel)
    Teiserver.cache_put(:discord_channel_cache, "id:#{channel.channel_id}", channel)
    {:ok, channel}
  end

  defp cache_channel(%DiscordChannel{} = channel) do
    Teiserver.cache_put(:discord_channel_cache, channel.name, channel)
    Teiserver.cache_put(:discord_channel_cache, "id:#{channel.channel_id}", channel)
    {:ok, channel}
  end

  defp cache_channel(channel), do: channel

  @spec pre_cache_discord_channels() :: :ok
  def pre_cache_discord_channels() do
    list_discord_channels()
    |> Enum.each(&cache_channel/1)
  end

  @doc """
  Given an integer it will take use the channel id, if given a string it will look up
  the channel name from the database Teiserver.Communication.DiscordChannel objects
  """
  @spec new_discord_message(String.t() | non_neg_integer(), String.t()) ::
          map | nil | {:error, String.t()}
  def new_discord_message(maybe_channel_id, message) do
    if use_discord?() do
      case get_channel_id_from_any(maybe_channel_id) do
        nil -> {:error, "No channel found"}
        channel_id -> Nostrum.Api.Message.create(channel_id, message)
      end
    else
      {:error, :discord_disabled}
    end
  end

  @spec edit_discord_message(non_neg_integer | String.t(), non_neg_integer, String.t()) ::
          map | nil | {:error, String.t()}
  def edit_discord_message(maybe_channel_id, message_id, new_message)
      when is_integer(message_id) do
    if use_discord?() do
      case get_channel_id_from_any(maybe_channel_id) do
        nil -> {:error, "No channel found"}
        channel_id -> Nostrum.Api.Message.edit(channel_id, message_id, content: new_message)
      end
    else
      {:error, :discord_disabled}
    end
  end

  @spec delete_discord_message(non_neg_integer | String.t(), non_neg_integer) ::
          map | nil | {:error, String.t()}
  def delete_discord_message(maybe_channel_id, message_id) do
    if use_discord?() do
      case get_channel_id_from_any(maybe_channel_id) do
        nil -> {:error, "No channel found"}
        channel_id -> Nostrum.Api.Message.delete(channel_id, message_id)
      end
    else
      {:error, :discord_disabled}
    end
  end

  @spec send_discord_dm(T.userid(), String.t()) :: map | nil | {:error, String.t()}
  def send_discord_dm(userid, message) do
    if use_discord?() do
      user = Account.get_user_by_id(userid)

      cond do
        user == nil ->
          {:error, "No user"}

        user.discord_dm_channel_id != nil ->
          new_discord_message(user.discord_dm_channel_id, message)

        user.discord_id != nil ->
          case Nostrum.Api.User.create_dm(user.discord_id) do
            {:ok, %{id: channel_id}} ->
              Account.update_cache_user(user.id, %{discord_dm_channel_id: channel_id})
              new_discord_message(channel_id, message)

            _ ->
              {:error, "Unable to created DM channel"}
          end

        true ->
          {:error, "No discord id for user"}
      end
    end
  end

  @spec create_discord_reaction(non_neg_integer | String.t(), non_neg_integer, String.t()) :: map | nil | {:error, String.t()}
  def create_discord_reaction(maybe_channel_id, message_id, icon) do
    if use_discord?() do
      case get_channel_id_from_any(maybe_channel_id) do
        nil -> {:error, "No channel found"}
        channel_id -> Nostrum.Api.Message.react(channel_id, message_id, icon)
      end
    else
      {:error, :discord_disabled}
    end
  end

  @spec get_channel_id_from_any(any) :: non_neg_integer() | nil
  defp get_channel_id_from_any(identifier) when is_integer(identifier) do
    if identifier < 999_999 do
      case get_discord_channel(identifier) do
        nil -> nil
        %{channel_id: channel_id} -> channel_id
      end
    else
      identifier
    end
  end

  defp get_channel_id_from_any(%{channel_id: channel_id}), do: channel_id

  defp get_channel_id_from_any(identifier) do
    case get_discord_channel(identifier) do
      nil -> nil
      %{channel_id: channel_id} -> channel_id
    end
  end

  @spec use_discord?() :: boolean
  def use_discord?() do
    Application.get_env(:teiserver, Teiserver)[:enable_discord_bridge]
  end

  @spec get_guild_id() :: integer | nil
  def get_guild_id() do
    Application.get_env(:teiserver, DiscordBridgeBot)[:guild_id]
  end
end
