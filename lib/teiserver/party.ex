defmodule Teiserver.Party do
  @moduledoc """
  Anything party related. These are only tachyon related parties, and don't
  have anything shared with the existing parties under Teiserver.Account

  The main reason is that the logic to tie parties with matchmaking is
  completely different and there are also a few other semantic differences
  with regard to invites.
  """

  alias Teiserver.Config
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Matchmaking
  alias Teiserver.Party

  @type id :: Party.Server.id()
  @type state :: Party.Server.state()

  @spec create_party(T.userid()) :: {:ok, id(), pid()} | {:error, reason :: term()}
  def create_party(user_id) do
    party_id = Party.Server.gen_party_id()

    case Party.Supervisor.start_party(party_id, user_id) do
      {:ok, pid} -> {:ok, party_id, pid}
      {:ok, pid, _info} -> {:ok, party_id, pid}
      :ignore -> {:error, :ignore}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec lookup(id()) :: pid() | nil
  defdelegate lookup(party_id), to: Party.Registry

  @spec get_state(id()) :: state() | nil
  defdelegate get_state(party_id), to: Party.Server

  @spec leave_party(id(), T.userid()) :: :ok | {:error, :invalid_party | :not_a_member}
  defdelegate leave_party(party_id, user_id), to: Party.Server

  @spec create_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :already_invited | :party_at_capacity}
  defdelegate create_invite(party_id, user_id), to: Party.Server

  @spec accept_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  defdelegate accept_invite(party_id, user_id), to: Party.Server

  @spec decline_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_invited}
  defdelegate decline_invite(party_id, user_id), to: Party.Server

  @spec cancel_invite(id(), T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :not_in_party | :not_invited}
  defdelegate cancel_invite(party_id, user_id), to: Party.Server

  @spec kick_user(id(), user_kicking :: T.userid(), kicked_user :: T.userid()) ::
          {:ok, state()} | {:error, :invalid_party | :invalid_target | :not_a_member}
  defdelegate kick_user(party_id, actor_id, target_id), to: Party.Server

  @spec join_queues(id(), [Matchmaking.queue_id()]) :: :ok | {:error, reason :: term()}
  defdelegate join_queues(party_id, queues), to: Party.Server

  @spec matchmaking_notify_cancel(id()) :: :ok
  defdelegate matchmaking_notify_cancel(party_id), to: Party.Server

  def setup_site_configs() do
    Config.add_site_config_type(%{
      key: Party.Server.max_size_key(),
      section: "Tachyon",
      type: "integer",
      permissions: ["Admin"],
      description: "Maximum number of member + invited for parties",
      default: 3
    })

    Config.add_site_config_type(%{
      key: Party.Server.invite_valid_duration_key(),
      section: "Tachyon",
      type: "integer",
      permissions: ["Admin"],
      description: "How long a party invite should be valid for (in seconds)",
      default: 60 * 5
    })
  end

  @spec update_max_size(integer()) :: :ok
  def update_max_size(new_max_size) do
    Config.update_site_config(Party.Server.max_size_key(), new_max_size)
    :ok
  end
end
