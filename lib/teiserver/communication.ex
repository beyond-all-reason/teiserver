defmodule Teiserver.Communication do
  @moduledoc """

  """
  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias Teiserver.Data.Types, as: T

  alias Teiserver.Communication.{TextCallback, TextCallbackLib}

  @spec lobby_text_callback(List.t()) :: Ecto.Query.t()
  def lobby_text_callback(args) do
    lobby_text_callback(nil, args)
  end

  @spec lobby_text_callback(Integer.t(), List.t()) :: Ecto.Query.t()
  def lobby_text_callback(id, args) do
    TextCallbackLib.query_text_callbacks()
    |> TextCallbackLib.search(%{id: id})
    |> TextCallbackLib.search(args[:search])
    |> TextCallbackLib.preload(args[:preload])
    |> TextCallbackLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of text_callbacks.

  ## Examples

      iex> list_text_callbacks()
      [%TextCallback{}, ...]

  """
  @spec list_text_callbacks(List.t()) :: List.t()
  def list_text_callbacks(args \\ []) do
    lobby_text_callback(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single text_callback.

  Raises `Ecto.NoResultsError` if the TextCallback does not exist.

  ## Examples

      iex> get_text_callback!(123)
      %TextCallback{}

      iex> get_text_callback!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_text_callback!(Integer.t() | List.t()) :: TextCallback.t()
  @spec get_text_callback!(Integer.t(), List.t()) :: TextCallback.t()
  def get_text_callback!(id) when not is_list(id) do
    lobby_text_callback(id, [])
    |> Repo.one!()
  end

  def get_text_callback!(args) do
    lobby_text_callback(nil, args)
    |> Repo.one!()
  end

  def get_text_callback!(id, args) do
    lobby_text_callback(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single text_callback.

  Returns `nil` if the TextCallback does not exist.

  ## Examples

      iex> get_text_callback(123)
      %TextCallback{}

      iex> get_text_callback(456)
      nil

  """
  @spec get_text_callback(Integer.t() | List.t()) :: TextCallback.t()
  @spec get_text_callback(Integer.t(), List.t()) :: TextCallback.t()
  def get_text_callback(id) when not is_list(id) do
    lobby_text_callback(id, [])
    |> Repo.one()
  end

  def get_text_callback(args) do
    lobby_text_callback(nil, args)
    |> Repo.one()
  end

  def get_text_callback(id, args) do
    lobby_text_callback(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a text_callback.

  ## Examples

      iex> create_text_callback(%{field: value})
      {:ok, %TextCallback{}}

      iex> create_text_callback(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_text_callback(map()) :: {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def create_text_callback(attrs \\ %{}) do
    %TextCallback{}
    |> TextCallback.changeset(attrs)
    |> Repo.insert()
    |> update_text_callback_cache()
  end

  @doc """
  Updates a text_callback.

  ## Examples

      iex> update_text_callback(text_callback, %{field: new_value})
      {:ok, %TextCallback{}}

      iex> update_text_callback(text_callback, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_text_callback(TextCallback.t(), map()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def update_text_callback(%TextCallback{} = text_callback, attrs) do
    text_callback
    |> TextCallback.changeset(attrs)
    |> Repo.update()
    |> update_text_callback_cache()
  end

  @doc """
  Deletes a TextCallback.

  ## Examples

      iex> delete_text_callback(text_callback)
      {:ok, %TextCallback{}}

      iex> delete_text_callback(text_callback)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_text_callback(TextCallback.t()) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  def delete_text_callback(%TextCallback{} = text_callback) do
    Repo.delete(text_callback)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking text_callback changes.

  ## Examples

      iex> change_text_callback(text_callback)
      %Ecto.Changeset{source: %TextCallback{}}

  """
  @spec change_text_callback(TextCallback.t()) :: Ecto.Changeset.t()
  def change_text_callback(%TextCallback{} = text_callback) do
    TextCallback.changeset(text_callback, %{})
  end

  @spec build_text_callback_cache() :: :ok
  defdelegate build_text_callback_cache, to: TextCallbackLib

  @spec update_text_callback_cache({:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}) ::
          {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_text_callback_cache(args), to: TextCallbackLib

  @spec lookup_text_callback_from_trigger(String.t()) :: TextCallback.t() | nil
  defdelegate lookup_text_callback_from_trigger(trigger), to: TextCallbackLib

  @spec can_trigger_callback?(non_neg_integer() | TextCallback.t(), non_neg_integer()) ::
          TextCallback.t() | nil
  defdelegate can_trigger_callback?(tc_id_or_tc, channel_id), to: TextCallbackLib

  @spec set_last_triggered_time(TextCallback.t(), non_neg_integer()) :: any
  defdelegate set_last_triggered_time(text_callback, channel_id), to: TextCallbackLib

  # Discord channels
  alias Teiserver.Communication.{DiscordChannel, DiscordChannelLib}

  @spec list_discord_channels() :: [DiscordChannel]
  defdelegate list_discord_channels(), to: DiscordChannelLib

  @spec list_discord_channels(list) :: [DiscordChannel]
  defdelegate list_discord_channels(args), to: DiscordChannelLib

  @spec get_discord_channel!(non_neg_integer()) :: DiscordChannel.t()
  defdelegate get_discord_channel!(discord_channel_id), to: DiscordChannelLib

  @spec get_discord_channel(non_neg_integer()) :: DiscordChannel.t() | nil
  defdelegate get_discord_channel(discord_channel_id), to: DiscordChannelLib

  @spec create_discord_channel() :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate create_discord_channel(), to: DiscordChannelLib

  @spec create_discord_channel(map) :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate create_discord_channel(attrs), to: DiscordChannelLib

  @spec update_discord_channel(DiscordChannel, map) ::
          {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate update_discord_channel(discord_channel, attrs), to: DiscordChannelLib

  @spec delete_discord_channel(DiscordChannel) :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate delete_discord_channel(discord_channel), to: DiscordChannelLib

  @spec change_discord_channel(DiscordChannel) :: Ecto.Changeset
  defdelegate change_discord_channel(discord_channel), to: DiscordChannelLib

  @spec change_discord_channel(DiscordChannel, map) :: Ecto.Changeset
  defdelegate change_discord_channel(discord_channel_type, attrs), to: DiscordChannelLib

  @spec pre_cache_discord_channels() :: :ok
  defdelegate pre_cache_discord_channels(), to: DiscordChannelLib

  @spec new_discord_message(String.t() | non_neg_integer(), String.t()) ::
          {:ok, Nostrum.Struct.Message.t()} | {:error, any}
  defdelegate new_discord_message(channel_id, message), to: DiscordChannelLib

  @spec get_discord_message(non_neg_integer | String.t(), non_neg_integer) ::
          {:ok, Nostrum.Struct.Message.t()} | {:error, any()} | nil
  defdelegate get_discord_message(channel_id, message_id), to: DiscordChannelLib

  @spec edit_discord_message(non_neg_integer | String.t(), non_neg_integer, String.t()) ::
          map | nil | {:error, String.t()}
  defdelegate edit_discord_message(channel_id, message_id, new_message), to: DiscordChannelLib

  @spec delete_discord_message(non_neg_integer | String.t(), non_neg_integer) ::
          map | nil | {:error, String.t()}
  defdelegate delete_discord_message(channel_id, message_id), to: DiscordChannelLib

  @spec send_discord_dm(T.userid(), String.t()) :: map | nil | {:error, String.t()}
  defdelegate send_discord_dm(userid, message), to: DiscordChannelLib

  @spec create_discord_reaction(non_neg_integer | String.t(), non_neg_integer, String.t()) ::
          map | nil | {:error, String.t()}
  defdelegate create_discord_reaction(channel_id, message_id, emoji), to: DiscordChannelLib

  @spec delete_discord_reaction(non_neg_integer | String.t(), non_neg_integer, String.t()) ::
          map | nil | {:error, String.t()}
  defdelegate delete_discord_reaction(channel_id, message_id, emoji), to: DiscordChannelLib

  @doc """
  Returns true if we are using discord in this environment and false if we are not.
  """
  @spec use_discord?() :: boolean
  defdelegate use_discord?(), to: DiscordChannelLib

  @spec get_guild_id() :: integer | nil
  defdelegate get_guild_id(), to: DiscordChannelLib
end
