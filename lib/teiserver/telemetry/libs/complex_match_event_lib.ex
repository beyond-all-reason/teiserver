defmodule Teiserver.Telemetry.ComplexMatchEventLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Telemetry.{ComplexMatchEvent, ComplexMatchEventTypeLib}
  alias Phoenix.PubSub

  @broadcast_event_types ~w()

  # Functions
  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-scanner-keyboard"

  # Helpers
  @spec log_complex_match_event(T.match_id(), T.userid() | nil, String.t(), integer(), map()) ::
          {:error, Ecto.Changeset.t()} | {:ok, ComplexMatchEvent.t()}
  def log_complex_match_event(match_id, userid, event_type_name, game_time, event_value) do
    event_type_id = ComplexMatchEventTypeLib.get_or_add_complex_match_event_type(event_type_name)

    result =
      Teiserver.Telemetry.create_complex_match_event(%{
        event_type_id: event_type_id,
        match_id: match_id,
        user_id: userid,
        game_time: game_time,
        value: event_value
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          if userid do
            PubSub.broadcast(
              Teiserver.PubSub,
              "teiserver_telemetry_complex_match_events",
              %{
                channel: "teiserver_telemetry_complex_match_events",
                userid: userid,
                match_id: match_id,
                event_type_name: event_type_name,
                game_time: game_time,
                value: event_value
              }
            )
          end
        end

        result

      _ ->
        result
    end
  end
end
