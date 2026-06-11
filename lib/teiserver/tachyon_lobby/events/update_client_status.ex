defmodule Teiserver.TachyonLobby.Events.UpdateClientStatus do
  @moduledoc """
  Updating client status, like ready/not ready and asset status
  """

  alias Teiserver.Account.User
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:user_id, :client_status_updates]
  defstruct [:user_id, :client_status_updates]

  @type client_status_update_data :: %{
          optional(:ready?) => boolean(),
          optional(:asset_status) => LT.Types.asset_status()
        }
  @type t() :: %__MODULE__{
          user_id: User.id(),
          client_status_updates: client_status_update_data()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateClientStatus do
  alias Teiserver.TachyonLobby.Events.UpdateClientStatus
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateClientStatus{} = ev, %LT.Aggregate{} = agg) do
    data =
      update_in(
        agg.data,
        [Access.key!(:players), ev.user_id],
        &Map.merge(&1, ev.client_status_updates)
      )

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> put_in([:players, ev.user_id], ev.client_status_updates)

    %{agg | data: data, changes: changes}
  end
end
