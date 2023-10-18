defmodule Teiserver.Communication do
  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  alias Teiserver.Communication.{Notification, NotificationLib}

  @doc """
  Returns the list of notifications.

  ## Examples

      iex> list_notifications()
      [%Notification{}, ...]

  """
  def list_notifications(args \\ []) do
    NotificationLib.get_notifications()
    |> NotificationLib.search(args[:search])
    |> NotificationLib.preload(args[:joins])
    |> NotificationLib.order(args[:order])
    |> Repo.all()
  end

  def list_user_notifications(user_id) do
    list_notifications(
      search: [
        user_id: user_id
      ]
    )
  end

  def list_user_notifications(user_id, :unread) do
    list_notifications(
      search: [
        user_id: user_id,
        read: false,
        expired: false,
        expires_after: Timex.local()
      ]
    )
  end

  def list_user_notifications(user_id, :expired) do
    list_notifications(
      search: [
        user_id: user_id,
        read: false,
        expired: true
      ]
    )
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the Notification does not exist.

  ## Examples

      iex> get_notification!(123)
      %Notification{}

      iex> get_notification!(456)
      ** (Ecto.NoResultsError)

  """
  def get_notification!(id, args \\ []) do
    NotificationLib.get_notifications()
    |> NotificationLib.search(%{id: id})
    |> NotificationLib.search(args[:search])
    |> NotificationLib.preload(args[:joins])
    |> Repo.one!()
  end

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{field: value})
      {:ok, %Notification{}}

      iex> create_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.

  ## Examples

      iex> update_notification(notification, %{field: new_value})
      {:ok, %Notification{}}

      iex> update_notification(notification, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}

      iex> delete_notification(notification)
      {:error, %Ecto.Changeset{}}

  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  def delete_all_notifications(user_id) do
    NotificationLib.get_notifications()
    |> NotificationLib.search(user_id: user_id)
    |> Repo.delete_all()
  end

  def delete_expired_notifications(user_id) do
    NotificationLib.get_notifications()
    |> NotificationLib.search(
      user_id: user_id,
      expired: true
    )
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.

  ## Examples

      iex> change_notification(notification)
      %Ecto.Changeset{source: %Notification{}}

  """
  def change_notification(%Notification{} = notification) do
    Notification.changeset(notification, %{})
  end

  @doc """
  Sends out notifications to the user(s) listed in user_ids
  """

  def notify(user_ids, data, expires, prevent_duplicates) when is_integer(expires) do
    notify(
      user_ids,
      data,
      Timex.shift(Timex.now(), days: expires),
      prevent_duplicates
    )
  end

  def notify(user_ids, data, expires, prevent_duplicates) when is_integer(user_ids) do
    notify([user_ids], data, expires, prevent_duplicates)
  end

  def notify(user_ids, data, expires, prevent_duplicates) do
    user_skips =
      if prevent_duplicates do
        query =
          from notifications in Notification,
            where: notifications.user_id in ^user_ids,
            where: notifications.read == false,
            where: notifications.expires > ^Timex.now(),
            where: notifications.title == ^data.title,
            where: notifications.body == ^data.body,
            select: notifications.user_id,
            distinct: true

        Repo.all(query)
      else
        []
      end

    user_ids
    |> Enum.filter(fn u -> not Enum.member?(user_skips, u) end)
    |> Enum.map(fn uid ->
      %Notification{}
      |> Notification.new_changeset(%{
        "user_id" => uid,
        "title" => data.title,
        "body" => data.body,
        "icon" => data.icon,
        "colour" => data.colour,
        "redirect" => data.redirect,
        "expires" => expires
      })
      |> Repo.insert!()
    end)
    |> Enum.map(fn data ->
      TeiserverWeb.Endpoint.broadcast(
        "communication_notification:#{data.user_id}",
        "new communication notifictation",
        %{
          id: data.id,
          title: data.title,
          body: data.body,
          icon: data.icon,
          colour: data.colour,
          redirect: data.redirect,
          expires: expires
        }
      )

      data
    end)
  end

  def notification_url(notification) do
    url = notification.redirect

    cond do
      String.contains?(url, "?") ->
        String.replace(url, "?", "?anid=#{notification.id}")

      String.contains?(url, "#") ->
        String.replace(url, "#", "?anid=#{notification.id}#")

      true ->
        url <> "?anid=#{notification.id}"
    end
  end

  def mark_all_notification_as_read(user_id) do
    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        update: [set: [read: true]]

    Repo.update_all(query, [])
  end

  def mark_notification_as_read(user_id, notification_id) do
    query =
      from n in Notification,
        where: n.id == ^notification_id,
        where: n.user_id == ^user_id,
        update: [set: [read: true]]

    Repo.update_all(query, [])
  end

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
  @spec create_text_callback(Map.t()) :: {:ok, TextCallback.t()} | {:error, Ecto.Changeset.t()}
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
  @spec update_text_callback(TextCallback.t(), Map.t()) ::
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

  @spec can_trigger_callback?(non_neg_integer() | TextCallback.t(), non_neg_integer()) :: TextCallback.t() | nil
  defdelegate can_trigger_callback?(tc_id_or_tc, channel_id), to: TextCallbackLib

  @spec set_last_triggered_time(TextCallback.t, non_neg_integer()) :: any
  defdelegate set_last_triggered_time(text_callback, channel_id), to: TextCallbackLib

  # Discord channels
  alias Teiserver.Communication.{DiscordChannel, DiscordChannelLib}

  @spec list_discord_channels() :: [DiscordChannel]
  defdelegate list_discord_channels(), to: DiscordChannelLib

  @spec list_discord_channels(list) :: [DiscordChannel]
  defdelegate list_discord_channels(args), to: DiscordChannelLib

  @spec get_discord_channel!(non_neg_integer()) :: DiscordChannel.t
  defdelegate get_discord_channel!(discord_channel_id), to: DiscordChannelLib

  @spec get_discord_channel(non_neg_integer()) :: DiscordChannel.t | nil
  defdelegate get_discord_channel(discord_channel_id), to: DiscordChannelLib

  @spec create_discord_channel() :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate create_discord_channel(), to: DiscordChannelLib

  @spec create_discord_channel(map) :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate create_discord_channel(attrs), to: DiscordChannelLib

  @spec update_discord_channel(DiscordChannel, map) :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate update_discord_channel(discord_channel, attrs), to: DiscordChannelLib

  @spec delete_discord_channel(DiscordChannel) :: {:ok, DiscordChannel} | {:error, Ecto.Changeset}
  defdelegate delete_discord_channel(discord_channel), to: DiscordChannelLib

  @spec change_discord_channel(DiscordChannel) :: Ecto.Changeset
  defdelegate change_discord_channel(discord_channel), to: DiscordChannelLib

  @spec change_discord_channel(DiscordChannel, map) :: Ecto.Changeset
  defdelegate change_discord_channel(discord_channel_type, attrs), to: DiscordChannelLib

  @spec pre_cache_discord_channels() :: :ok
  defdelegate pre_cache_discord_channels(), to: DiscordChannelLib

  @spec new_discord_message(String.t | non_neg_integer(), String.t()) :: map | nil | {:error, String.t}
  defdelegate new_discord_message(channel_id, message), to: DiscordChannelLib

  @spec edit_discord_message(non_neg_integer | String.t, non_neg_integer, String.t) :: map | nil | {:error, String.t}
  defdelegate edit_discord_message(channel_id, message_id, new_message), to: DiscordChannelLib

  @spec delete_discord_message(non_neg_integer | String.t, non_neg_integer) :: map | nil | {:error, String.t}
  defdelegate delete_discord_message(channel_id, message_id), to: DiscordChannelLib
end
