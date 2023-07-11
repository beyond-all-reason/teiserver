defmodule Teiserver.Tachyon.Handlers.Lobby.UpdateStatusRequest do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Lobby.UpdateStatusResponse
  alias Teiserver.{Lobby, Coordinator, Client, Account}

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "lobby/updateStatus/request" => &execute/3
    }
  end

  @keys %{
    "is_player" => :player
  }

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) ::
          {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, status, _meta) do
    existing = Client.get_client_by_id(conn.userid)

    updates =
      @keys
      |> Enum.filter(fn {string_key, _atom_key} ->
        Map.has_key?(status, string_key)
      end)
      |> Map.new(fn {string_key, atom_key} ->
        {atom_key, status[string_key]}
      end)

    potential_new = Map.merge(existing, updates)

    _result =
      if Lobby.allow?(conn.userid, :mybattlestatus, conn.lobby_id) do
        case Coordinator.attempt_battlestatus_update(potential_new, conn.lobby_id) do
          {true, allowed_client} ->
            updated_values =
              updates
              |> Map.keys()
              |> Map.new(fn key ->
                {key, Map.get(allowed_client, key)}
              end)

            Account.merge_update_client(conn.userid, updated_values)

          nil ->
            :ok
        end
      end

    response = UpdateStatusResponse.generate()

    {response, conn}
  end
end
