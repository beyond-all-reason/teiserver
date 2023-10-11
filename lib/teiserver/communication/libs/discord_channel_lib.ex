defmodule Teiserver.Communication.DiscordChannelLib do
  @moduledoc false
  use CentralWeb, :library_newform
  alias Teiserver.Communication.{DiscordChannel, DiscordChannelQueries}

  @spec special_channels() :: [String.t]
  def special_channels do
    [
      "Announcements",
      "Main chat",
      "Looking for players",
      "New player chat",
      "Public moderation log",
      "Overwatch reports",
      "Moderation reports",
      "Server updates",
      "Error updates"
    ]
  end

  @spec counter_channels() :: [String.t]
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
  @spec get_discord_channel!(non_neg_integer()) :: DiscordChannel.t
  def get_discord_channel!(discord_channel_id) do
    [id: discord_channel_id]
    |> DiscordChannelQueries.query_discord_channels()
    |> Repo.one!()
  end

  @spec get_discord_channel(non_neg_integer()) :: DiscordChannel.t | nil
  def get_discord_channel(discord_channel_id) do
    [id: discord_channel_id]
    |> DiscordChannelQueries.query_discord_channels()
    |> Repo.one()
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
end
