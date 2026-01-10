defmodule Teiserver.Telemetry do
  @moduledoc false
  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias Teiserver.Data.Types, as: T

  # Erlang telemetry stuff
  alias Teiserver.Telemetry.TelemetryLib

  @spec get_totals_and_reset() :: map()
  defdelegate get_totals_and_reset(), to: TelemetryLib

  @spec increment(any) :: :ok
  defdelegate increment(key), to: TelemetryLib

  @spec cast_to_server(any) :: :ok
  defdelegate cast_to_server(msg), to: TelemetryLib

  @spec metrics() :: List.t()
  defdelegate metrics(), to: TelemetryLib

  # ------------------------
  # ------------------------ Complex Event Types ------------------------
  # ------------------------

  # Complex client event types
  alias Teiserver.Telemetry.ComplexClientEventTypeLib

  @spec get_or_add_complex_client_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_complex_client_event_type(name), to: ComplexClientEventTypeLib

  @spec list_complex_client_event_types() :: [ComplexServerEventType.t()]
  defdelegate list_complex_client_event_types(), to: ComplexClientEventTypeLib

  @spec list_complex_client_event_types(list) :: [ComplexServerEventType.t()]
  defdelegate list_complex_client_event_types(args), to: ComplexClientEventTypeLib

  @spec get_complex_client_event_type!(non_neg_integer) :: ComplexServerEventType.t()
  defdelegate get_complex_client_event_type!(id), to: ComplexClientEventTypeLib

  @spec get_complex_client_event_type!(non_neg_integer, list) :: ComplexServerEventType.t()
  defdelegate get_complex_client_event_type!(id, args), to: ComplexClientEventTypeLib

  @spec create_complex_client_event_type() ::
          {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate create_complex_client_event_type(), to: ComplexClientEventTypeLib

  @spec create_complex_client_event_type(map) ::
          {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate create_complex_client_event_type(attrs), to: ComplexClientEventTypeLib

  @spec update_complex_client_event_type(ComplexServerEventType.t(), map) ::
          {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate update_complex_client_event_type(complex_client_event_type, attrs),
    to: ComplexClientEventTypeLib

  @spec delete_complex_client_event_type(ComplexServerEventType) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_complex_client_event_type(complex_client_event_type),
    to: ComplexClientEventTypeLib

  @spec change_complex_client_event_type(ComplexServerEventType) :: Ecto.Changeset
  defdelegate change_complex_client_event_type(complex_client_event_type),
    to: ComplexClientEventTypeLib

  @spec change_complex_client_event_type(ComplexServerEventType, map) :: Ecto.Changeset
  defdelegate change_complex_client_event_type(complex_client_event_type, attrs),
    to: ComplexClientEventTypeLib

  # Complex lobby event types
  alias Teiserver.Telemetry.ComplexLobbyEventTypeLib

  @spec get_or_add_complex_lobby_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_complex_lobby_event_type(name), to: ComplexLobbyEventTypeLib

  @spec list_complex_lobby_event_types() :: [ComplexServerEventType]
  defdelegate list_complex_lobby_event_types(), to: ComplexLobbyEventTypeLib

  @spec list_complex_lobby_event_types(list) :: [ComplexServerEventType]
  defdelegate list_complex_lobby_event_types(args), to: ComplexLobbyEventTypeLib

  @spec get_complex_lobby_event_type!(non_neg_integer) :: ComplexServerEventType
  defdelegate get_complex_lobby_event_type!(id), to: ComplexLobbyEventTypeLib

  @spec get_complex_lobby_event_type!(non_neg_integer, list) :: ComplexServerEventType
  defdelegate get_complex_lobby_event_type!(id, args), to: ComplexLobbyEventTypeLib

  @spec create_complex_lobby_event_type() ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_lobby_event_type(), to: ComplexLobbyEventTypeLib

  @spec create_complex_lobby_event_type(map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_lobby_event_type(attrs), to: ComplexLobbyEventTypeLib

  @spec update_complex_lobby_event_type(ComplexServerEventType, map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_complex_lobby_event_type(complex_lobby_event_type, attrs),
    to: ComplexLobbyEventTypeLib

  @spec delete_complex_lobby_event_type(ComplexServerEventType) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_complex_lobby_event_type(complex_lobby_event_type),
    to: ComplexLobbyEventTypeLib

  @spec change_complex_lobby_event_type(ComplexServerEventType) :: Ecto.Changeset
  defdelegate change_complex_lobby_event_type(complex_lobby_event_type),
    to: ComplexLobbyEventTypeLib

  @spec change_complex_lobby_event_type(ComplexServerEventType, map) :: Ecto.Changeset
  defdelegate change_complex_lobby_event_type(complex_lobby_event_type, attrs),
    to: ComplexLobbyEventTypeLib

  # Complex match event types
  alias Teiserver.Telemetry.ComplexMatchEventTypeLib

  @spec get_or_add_complex_match_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_complex_match_event_type(name), to: ComplexMatchEventTypeLib

  @spec list_complex_match_event_types() :: [ComplexServerEventType]
  defdelegate list_complex_match_event_types(), to: ComplexMatchEventTypeLib

  @spec list_complex_match_event_types(list) :: [ComplexServerEventType]
  defdelegate list_complex_match_event_types(args), to: ComplexMatchEventTypeLib

  @spec get_complex_match_event_type!(non_neg_integer) :: ComplexServerEventType
  defdelegate get_complex_match_event_type!(id), to: ComplexMatchEventTypeLib

  @spec get_complex_match_event_type!(non_neg_integer, list) :: ComplexServerEventType
  defdelegate get_complex_match_event_type!(id, args), to: ComplexMatchEventTypeLib

  @spec create_complex_match_event_type() ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_match_event_type(), to: ComplexMatchEventTypeLib

  @spec create_complex_match_event_type(map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_match_event_type(attrs), to: ComplexMatchEventTypeLib

  @spec update_complex_match_event_type(ComplexServerEventType, map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_complex_match_event_type(complex_match_event_type, attrs),
    to: ComplexMatchEventTypeLib

  @spec delete_complex_match_event_type(ComplexServerEventType) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_complex_match_event_type(complex_match_event_type),
    to: ComplexMatchEventTypeLib

  @spec change_complex_match_event_type(ComplexServerEventType) :: Ecto.Changeset
  defdelegate change_complex_match_event_type(complex_match_event_type),
    to: ComplexMatchEventTypeLib

  @spec change_complex_match_event_type(ComplexServerEventType, map) :: Ecto.Changeset
  defdelegate change_complex_match_event_type(complex_match_event_type, attrs),
    to: ComplexMatchEventTypeLib

  # Complex server event types
  alias Teiserver.Telemetry.{ComplexServerEventType, ComplexServerEventTypeLib}

  @spec get_or_add_complex_server_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_complex_server_event_type(name), to: ComplexServerEventTypeLib

  @spec list_complex_server_event_types() :: [ComplexServerEventType]
  defdelegate list_complex_server_event_types(), to: ComplexServerEventTypeLib

  @spec list_complex_server_event_types(list) :: [ComplexServerEventType]
  defdelegate list_complex_server_event_types(args), to: ComplexServerEventTypeLib

  @spec get_complex_server_event_type!(non_neg_integer) :: ComplexServerEventType
  defdelegate get_complex_server_event_type!(id), to: ComplexServerEventTypeLib

  @spec get_complex_server_event_type!(non_neg_integer, list) :: ComplexServerEventType
  defdelegate get_complex_server_event_type!(id, args), to: ComplexServerEventTypeLib

  @spec create_complex_server_event_type() ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_server_event_type(), to: ComplexServerEventTypeLib

  @spec create_complex_server_event_type(map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_complex_server_event_type(attrs), to: ComplexServerEventTypeLib

  @spec update_complex_server_event_type(ComplexServerEventType, map) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_complex_server_event_type(complex_server_event_type, attrs),
    to: ComplexServerEventTypeLib

  @spec delete_complex_server_event_type(ComplexServerEventType) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_complex_server_event_type(complex_server_event_type),
    to: ComplexServerEventTypeLib

  @spec change_complex_server_event_type(ComplexServerEventType) :: Ecto.Changeset
  defdelegate change_complex_server_event_type(complex_server_event_type),
    to: ComplexServerEventTypeLib

  @spec change_complex_server_event_type(ComplexServerEventType, map) :: Ecto.Changeset
  defdelegate change_complex_server_event_type(complex_server_event_type, attrs),
    to: ComplexServerEventTypeLib

  # ------------------------
  # ------------------------ Simple Event Types ------------------------
  # ------------------------

  # Simple client event types
  alias Teiserver.Telemetry.SimpleClientEventTypeLib

  @spec get_or_add_simple_client_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_simple_client_event_type(name), to: SimpleClientEventTypeLib

  @spec list_simple_client_event_types() :: [SimpleServerEventType]
  defdelegate list_simple_client_event_types(), to: SimpleClientEventTypeLib

  @spec list_simple_client_event_types(list) :: [SimpleServerEventType]
  defdelegate list_simple_client_event_types(args), to: SimpleClientEventTypeLib

  @spec get_simple_client_event_type!(non_neg_integer) :: SimpleServerEventType
  defdelegate get_simple_client_event_type!(id), to: SimpleClientEventTypeLib

  @spec get_simple_client_event_type!(non_neg_integer, list) :: SimpleServerEventType
  defdelegate get_simple_client_event_type!(id, args), to: SimpleClientEventTypeLib

  @spec create_simple_client_event_type() ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_client_event_type(), to: SimpleClientEventTypeLib

  @spec create_simple_client_event_type(map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_client_event_type(attrs), to: SimpleClientEventTypeLib

  @spec update_simple_client_event_type(SimpleServerEventType, map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_simple_client_event_type(simple_client_event_type, attrs),
    to: SimpleClientEventTypeLib

  @spec delete_simple_client_event_type(SimpleServerEventType) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_simple_client_event_type(simple_client_event_type),
    to: SimpleClientEventTypeLib

  @spec change_simple_client_event_type(SimpleServerEventType) :: Ecto.Changeset
  defdelegate change_simple_client_event_type(simple_client_event_type),
    to: SimpleClientEventTypeLib

  @spec change_simple_client_event_type(SimpleServerEventType, map) :: Ecto.Changeset
  defdelegate change_simple_client_event_type(simple_client_event_type, attrs),
    to: SimpleClientEventTypeLib

  # Simple lobby event types
  alias Teiserver.Telemetry.SimpleLobbyEventTypeLib

  @spec get_or_add_simple_lobby_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_simple_lobby_event_type(name), to: SimpleLobbyEventTypeLib

  @spec list_simple_lobby_event_types() :: [SimpleServerEventType]
  defdelegate list_simple_lobby_event_types(), to: SimpleLobbyEventTypeLib

  @spec list_simple_lobby_event_types(list) :: [SimpleServerEventType]
  defdelegate list_simple_lobby_event_types(args), to: SimpleLobbyEventTypeLib

  @spec get_simple_lobby_event_type!(non_neg_integer) :: SimpleServerEventType
  defdelegate get_simple_lobby_event_type!(id), to: SimpleLobbyEventTypeLib

  @spec get_simple_lobby_event_type!(non_neg_integer, list) :: SimpleServerEventType
  defdelegate get_simple_lobby_event_type!(id, args), to: SimpleLobbyEventTypeLib

  @spec create_simple_lobby_event_type() ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_lobby_event_type(), to: SimpleLobbyEventTypeLib

  @spec create_simple_lobby_event_type(map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_lobby_event_type(attrs), to: SimpleLobbyEventTypeLib

  @spec update_simple_lobby_event_type(SimpleServerEventType, map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_simple_lobby_event_type(simple_lobby_event_type, attrs),
    to: SimpleLobbyEventTypeLib

  @spec delete_simple_lobby_event_type(SimpleServerEventType) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_simple_lobby_event_type(simple_lobby_event_type), to: SimpleLobbyEventTypeLib

  @spec change_simple_lobby_event_type(SimpleServerEventType) :: Ecto.Changeset
  defdelegate change_simple_lobby_event_type(simple_lobby_event_type), to: SimpleLobbyEventTypeLib

  @spec change_simple_lobby_event_type(SimpleServerEventType, map) :: Ecto.Changeset
  defdelegate change_simple_lobby_event_type(simple_lobby_event_type, attrs),
    to: SimpleLobbyEventTypeLib

  # Simple match event types
  alias Teiserver.Telemetry.SimpleMatchEventTypeLib

  @spec get_or_add_simple_match_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_simple_match_event_type(name), to: SimpleMatchEventTypeLib

  @spec list_simple_match_event_types() :: [SimpleServerEventType]
  defdelegate list_simple_match_event_types(), to: SimpleMatchEventTypeLib

  @spec list_simple_match_event_types(list) :: [SimpleServerEventType]
  defdelegate list_simple_match_event_types(args), to: SimpleMatchEventTypeLib

  @spec get_simple_match_event_type!(non_neg_integer) :: SimpleServerEventType
  defdelegate get_simple_match_event_type!(id), to: SimpleMatchEventTypeLib

  @spec get_simple_match_event_type!(non_neg_integer, list) :: SimpleServerEventType
  defdelegate get_simple_match_event_type!(id, args), to: SimpleMatchEventTypeLib

  @spec create_simple_match_event_type() ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_match_event_type(), to: SimpleMatchEventTypeLib

  @spec create_simple_match_event_type(map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_match_event_type(attrs), to: SimpleMatchEventTypeLib

  @spec update_simple_match_event_type(SimpleServerEventType, map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_simple_match_event_type(simple_match_event_type, attrs),
    to: SimpleMatchEventTypeLib

  @spec delete_simple_match_event_type(SimpleServerEventType) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_simple_match_event_type(simple_match_event_type), to: SimpleMatchEventTypeLib

  @spec change_simple_match_event_type(SimpleServerEventType) :: Ecto.Changeset
  defdelegate change_simple_match_event_type(simple_match_event_type), to: SimpleMatchEventTypeLib

  @spec change_simple_match_event_type(SimpleServerEventType, map) :: Ecto.Changeset
  defdelegate change_simple_match_event_type(simple_match_event_type, attrs),
    to: SimpleMatchEventTypeLib

  # Simple server event types
  alias Teiserver.Telemetry.{SimpleServerEventType, SimpleServerEventTypeLib}

  @spec get_or_add_simple_server_event_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_simple_server_event_type(name), to: SimpleServerEventTypeLib

  @spec list_simple_server_event_types() :: [SimpleServerEventType]
  defdelegate list_simple_server_event_types(), to: SimpleServerEventTypeLib

  @spec list_simple_server_event_types(list) :: [SimpleServerEventType]
  defdelegate list_simple_server_event_types(args), to: SimpleServerEventTypeLib

  @spec get_simple_server_event_type!(non_neg_integer) :: SimpleServerEventType
  defdelegate get_simple_server_event_type!(id), to: SimpleServerEventTypeLib

  @spec get_simple_server_event_type!(non_neg_integer, list) :: SimpleServerEventType
  defdelegate get_simple_server_event_type!(id, args), to: SimpleServerEventTypeLib

  @spec create_simple_server_event_type() ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_server_event_type(), to: SimpleServerEventTypeLib

  @spec create_simple_server_event_type(map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate create_simple_server_event_type(attrs), to: SimpleServerEventTypeLib

  @spec update_simple_server_event_type(SimpleServerEventType, map) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate update_simple_server_event_type(simple_server_event_type, attrs),
    to: SimpleServerEventTypeLib

  @spec delete_simple_server_event_type(SimpleServerEventType) ::
          {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_simple_server_event_type(simple_server_event_type),
    to: SimpleServerEventTypeLib

  @spec change_simple_server_event_type(SimpleServerEventType) :: Ecto.Changeset
  defdelegate change_simple_server_event_type(simple_server_event_type),
    to: SimpleServerEventTypeLib

  @spec change_simple_server_event_type(SimpleServerEventType, map) :: Ecto.Changeset
  defdelegate change_simple_server_event_type(simple_server_event_type, attrs),
    to: SimpleServerEventTypeLib

  # ------------------------
  # ------------------------ Complex Events ------------------------
  # ------------------------
  # Complex client events
  alias Teiserver.Telemetry.{ComplexClientEvent, ComplexClientEventLib}

  @spec log_complex_client_event(T.userid(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexClientEvent}
  defdelegate log_complex_client_event(userid, event_type_name, value), to: ComplexClientEventLib

  @spec list_complex_client_events() :: [ComplexServerEvent]
  defdelegate list_complex_client_events(), to: ComplexClientEventLib

  @spec list_complex_client_events(list) :: [ComplexServerEvent]
  defdelegate list_complex_client_events(args), to: ComplexClientEventLib

  @spec get_complex_client_event!(non_neg_integer) :: ComplexServerEvent
  defdelegate get_complex_client_event!(id), to: ComplexClientEventLib

  @spec get_complex_client_event!(non_neg_integer, list) :: ComplexServerEvent
  defdelegate get_complex_client_event!(id, args), to: ComplexClientEventLib

  @spec create_complex_client_event() :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_client_event(), to: ComplexClientEventLib

  @spec create_complex_client_event(map) :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_client_event(attrs), to: ComplexClientEventLib

  @spec update_complex_client_event(ComplexServerEvent, map) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_complex_client_event(complex_client_event, attrs), to: ComplexClientEventLib

  @spec delete_complex_client_event(ComplexServerEvent) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_complex_client_event(complex_client_event), to: ComplexClientEventLib

  @spec change_complex_client_event(ComplexServerEvent) :: Ecto.Changeset
  defdelegate change_complex_client_event(complex_client_event), to: ComplexClientEventLib

  @spec change_complex_client_event(ComplexServerEvent, map) :: Ecto.Changeset
  defdelegate change_complex_client_event(complex_client_event_type, attrs),
    to: ComplexClientEventLib

  # Complex lobby events
  alias Teiserver.Telemetry.{ComplexLobbyEvent, ComplexLobbyEventLib}

  @spec log_complex_lobby_event(T.userid(), T.match_id(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexLobbyEvent}
  defdelegate log_complex_lobby_event(userid, match_id, event_type_name, value),
    to: ComplexLobbyEventLib

  @spec list_complex_lobby_events() :: [ComplexServerEvent]
  defdelegate list_complex_lobby_events(), to: ComplexLobbyEventLib

  @spec list_complex_lobby_events(list) :: [ComplexServerEvent]
  defdelegate list_complex_lobby_events(args), to: ComplexLobbyEventLib

  @spec get_complex_lobby_event!(non_neg_integer) :: ComplexServerEvent
  defdelegate get_complex_lobby_event!(id), to: ComplexLobbyEventLib

  @spec get_complex_lobby_event!(non_neg_integer, list) :: ComplexServerEvent
  defdelegate get_complex_lobby_event!(id, args), to: ComplexLobbyEventLib

  @spec create_complex_lobby_event() :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_lobby_event(), to: ComplexLobbyEventLib

  @spec create_complex_lobby_event(map) :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_lobby_event(attrs), to: ComplexLobbyEventLib

  @spec update_complex_lobby_event(ComplexServerEvent, map) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_complex_lobby_event(complex_lobby_event, attrs), to: ComplexLobbyEventLib

  @spec delete_complex_lobby_event(ComplexServerEvent) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_complex_lobby_event(complex_lobby_event), to: ComplexLobbyEventLib

  @spec change_complex_lobby_event(ComplexServerEvent) :: Ecto.Changeset
  defdelegate change_complex_lobby_event(complex_lobby_event), to: ComplexLobbyEventLib

  @spec change_complex_lobby_event(ComplexServerEvent, map) :: Ecto.Changeset
  defdelegate change_complex_lobby_event(complex_lobby_event_type, attrs),
    to: ComplexLobbyEventLib

  # Complex match events
  alias Teiserver.Telemetry.{ComplexMatchEvent, ComplexMatchEventLib}

  @spec log_complex_match_event(T.userid(), T.match_id(), String.t(), non_neg_integer, map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexMatchEvent}
  defdelegate log_complex_match_event(userid, match_id, event_type_name, game_time, value),
    to: ComplexMatchEventLib

  @spec list_complex_match_events() :: [ComplexServerEvent]
  defdelegate list_complex_match_events(), to: ComplexMatchEventLib

  @spec list_complex_match_events(list) :: [ComplexServerEvent]
  defdelegate list_complex_match_events(args), to: ComplexMatchEventLib

  @spec get_complex_match_event!(non_neg_integer) :: ComplexServerEvent
  defdelegate get_complex_match_event!(id), to: ComplexMatchEventLib

  @spec get_complex_match_event!(non_neg_integer, list) :: ComplexServerEvent
  defdelegate get_complex_match_event!(id, args), to: ComplexMatchEventLib

  @spec create_complex_match_event() :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_match_event(), to: ComplexMatchEventLib

  @spec create_complex_match_event(map) :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_match_event(attrs), to: ComplexMatchEventLib

  @spec update_complex_match_event(ComplexServerEvent, map) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_complex_match_event(complex_match_event, attrs), to: ComplexMatchEventLib

  @spec delete_complex_match_event(ComplexServerEvent) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_complex_match_event(complex_match_event), to: ComplexMatchEventLib

  @spec change_complex_match_event(ComplexServerEvent) :: Ecto.Changeset
  defdelegate change_complex_match_event(complex_match_event), to: ComplexMatchEventLib

  @spec change_complex_match_event(ComplexServerEvent, map) :: Ecto.Changeset
  defdelegate change_complex_match_event(complex_match_event_type, attrs),
    to: ComplexMatchEventLib

  # Complex server events
  alias Teiserver.Telemetry.{ComplexServerEvent, ComplexServerEventLib}

  @spec log_complex_server_event(T.userid() | nil, String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexServerEvent}
  defdelegate log_complex_server_event(userid, event_type_name, value), to: ComplexServerEventLib

  @spec list_complex_server_events() :: [ComplexServerEvent]
  defdelegate list_complex_server_events(), to: ComplexServerEventLib

  @spec list_complex_server_events(list) :: [ComplexServerEvent]
  defdelegate list_complex_server_events(args), to: ComplexServerEventLib

  @spec get_complex_server_event!(non_neg_integer) :: ComplexServerEvent
  defdelegate get_complex_server_event!(id), to: ComplexServerEventLib

  @spec get_complex_server_event!(non_neg_integer, list) :: ComplexServerEvent
  defdelegate get_complex_server_event!(id, args), to: ComplexServerEventLib

  @spec create_complex_server_event() :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_server_event(), to: ComplexServerEventLib

  @spec create_complex_server_event(map) :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_server_event(attrs), to: ComplexServerEventLib

  @spec update_complex_server_event(ComplexServerEvent, map) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_complex_server_event(complex_server_event, attrs), to: ComplexServerEventLib

  @spec delete_complex_server_event(ComplexServerEvent) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_complex_server_event(complex_server_event), to: ComplexServerEventLib

  @spec change_complex_server_event(ComplexServerEvent) :: Ecto.Changeset
  defdelegate change_complex_server_event(complex_server_event), to: ComplexServerEventLib

  @spec change_complex_server_event(ComplexServerEvent, map) :: Ecto.Changeset
  defdelegate change_complex_server_event(complex_server_event_type, attrs),
    to: ComplexServerEventLib

  # ------------------------
  # ------------------------ Simple Events ------------------------
  # ------------------------
  # Simple client events
  alias Teiserver.Telemetry.{SimpleClientEvent, SimpleClientEventLib}

  @spec log_simple_client_event(T.userid(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, SimpleClientEvent}
  defdelegate log_simple_client_event(userid, event_type_name), to: SimpleClientEventLib

  @spec list_simple_client_events() :: [SimpleServerEvent]
  defdelegate list_simple_client_events(), to: SimpleClientEventLib

  @spec list_simple_client_events(list) :: [SimpleServerEvent]
  defdelegate list_simple_client_events(args), to: SimpleClientEventLib

  @spec get_simple_client_event!(non_neg_integer) :: SimpleServerEvent
  defdelegate get_simple_client_event!(id), to: SimpleClientEventLib

  @spec get_simple_client_event!(non_neg_integer, list) :: SimpleServerEvent
  defdelegate get_simple_client_event!(id, args), to: SimpleClientEventLib

  @spec create_simple_client_event() :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_client_event(), to: SimpleClientEventLib

  @spec create_simple_client_event(map) :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_client_event(attrs), to: SimpleClientEventLib

  @spec update_simple_client_event(SimpleServerEvent, map) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_simple_client_event(simple_client_event, attrs), to: SimpleClientEventLib

  @spec delete_simple_client_event(SimpleServerEvent) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_simple_client_event(simple_client_event), to: SimpleClientEventLib

  @spec change_simple_client_event(SimpleServerEvent) :: Ecto.Changeset
  defdelegate change_simple_client_event(simple_client_event), to: SimpleClientEventLib

  @spec change_simple_client_event(SimpleServerEvent, map) :: Ecto.Changeset
  defdelegate change_simple_client_event(simple_client_event_type, attrs),
    to: SimpleClientEventLib

  # Simple lobby events
  alias Teiserver.Telemetry.{SimpleLobbyEvent, SimpleLobbyEventLib}

  @spec log_simple_lobby_event(T.userid(), T.match_id(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, SimpleLobbyEvent}
  defdelegate log_simple_lobby_event(userid, match_id, event_type_name), to: SimpleLobbyEventLib

  @spec list_simple_lobby_events() :: [SimpleLobbyEvent.t()]
  defdelegate list_simple_lobby_events(), to: SimpleLobbyEventLib

  @spec list_simple_lobby_events(list) :: [SimpleLobbyEvent.t()]
  defdelegate list_simple_lobby_events(args), to: SimpleLobbyEventLib

  @spec get_simple_lobby_event!(non_neg_integer) :: SimpleLobbyEvent.t()
  defdelegate get_simple_lobby_event!(id), to: SimpleLobbyEventLib

  @spec get_simple_lobby_event!(non_neg_integer, list) :: SimpleLobbyEvent.t()
  defdelegate get_simple_lobby_event!(id, args), to: SimpleLobbyEventLib

  @spec create_simple_lobby_event() :: {:ok, SimpleLobbyEvent.t()} | {:error, Ecto.Changeset}
  defdelegate create_simple_lobby_event(), to: SimpleLobbyEventLib

  @spec create_simple_lobby_event(map) :: {:ok, SimpleLobbyEvent.t()} | {:error, Ecto.Changeset}
  defdelegate create_simple_lobby_event(attrs), to: SimpleLobbyEventLib

  @spec update_simple_lobby_event(SimpleLobbyEvent.t(), map) ::
          {:ok, SimpleLobbyEvent.t()} | {:error, Ecto.Changeset}
  defdelegate update_simple_lobby_event(simple_lobby_event, attrs), to: SimpleLobbyEventLib

  @spec delete_simple_lobby_event(SimpleLobbyEvent.t()) ::
          {:ok, SimpleLobbyEvent.t()} | {:error, Ecto.Changeset}
  defdelegate delete_simple_lobby_event(simple_lobby_event), to: SimpleLobbyEventLib

  @spec change_simple_lobby_event(SimpleLobbyEvent.t()) :: Ecto.Changeset
  defdelegate change_simple_lobby_event(simple_lobby_event), to: SimpleLobbyEventLib

  @spec change_simple_lobby_event(SimpleLobbyEvent.t(), map) :: Ecto.Changeset
  defdelegate change_simple_lobby_event(simple_lobby_event_type, attrs), to: SimpleLobbyEventLib

  # Simple match events
  alias Teiserver.Telemetry.{SimpleMatchEvent, SimpleMatchEventLib}

  @spec log_simple_match_event(T.userid(), T.match_id(), String.t(), non_neg_integer) ::
          {:error, Ecto.Changeset} | {:ok, SimpleMatchEvent}
  defdelegate log_simple_match_event(userid, match_id, event_type_name, game_time),
    to: SimpleMatchEventLib

  @spec list_simple_match_events() :: [SimpleMatchEvent.t()]
  defdelegate list_simple_match_events(), to: SimpleMatchEventLib

  @spec list_simple_match_events(list) :: [SimpleMatchEvent.t()]
  defdelegate list_simple_match_events(args), to: SimpleMatchEventLib

  @spec get_simple_match_event!(non_neg_integer) :: SimpleMatchEvent.t()
  defdelegate get_simple_match_event!(id), to: SimpleMatchEventLib

  @spec get_simple_match_event!(non_neg_integer, list) :: SimpleMatchEvent.t()
  defdelegate get_simple_match_event!(id, args), to: SimpleMatchEventLib

  @spec create_simple_match_event() :: {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset}
  defdelegate create_simple_match_event(), to: SimpleMatchEventLib

  @spec create_simple_match_event(map) :: {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset}
  defdelegate create_simple_match_event(attrs), to: SimpleMatchEventLib

  @spec update_simple_match_event(SimpleMatchEvent.t(), map) ::
          {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset}
  defdelegate update_simple_match_event(simple_match_event, attrs), to: SimpleMatchEventLib

  @spec delete_simple_match_event(SimpleMatchEvent.t()) ::
          {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset}
  defdelegate delete_simple_match_event(simple_match_event), to: SimpleMatchEventLib

  @spec change_simple_match_event(SimpleMatchEvent.t()) :: Ecto.Changeset
  defdelegate change_simple_match_event(simple_match_event), to: SimpleMatchEventLib

  @spec change_simple_match_event(SimpleMatchEvent.t(), map) :: Ecto.Changeset
  defdelegate change_simple_match_event(simple_match_event_type, attrs), to: SimpleMatchEventLib

  # Simple server events
  alias Teiserver.Telemetry.{SimpleServerEvent, SimpleServerEventLib}

  @spec log_simple_server_event(T.userid(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, SimpleServerEvent}
  defdelegate log_simple_server_event(userid, event_type_name), to: SimpleServerEventLib

  @spec list_simple_server_events() :: [SimpleServerEvent]
  defdelegate list_simple_server_events(), to: SimpleServerEventLib

  @spec list_simple_server_events(list) :: [SimpleServerEvent]
  defdelegate list_simple_server_events(args), to: SimpleServerEventLib

  @spec get_simple_server_event!(non_neg_integer) :: SimpleServerEvent
  defdelegate get_simple_server_event!(id), to: SimpleServerEventLib

  @spec get_simple_server_event!(non_neg_integer, list) :: SimpleServerEvent
  defdelegate get_simple_server_event!(id, args), to: SimpleServerEventLib

  @spec create_simple_server_event() :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_server_event(), to: SimpleServerEventLib

  @spec create_simple_server_event(map) :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_server_event(attrs), to: SimpleServerEventLib

  @spec update_simple_server_event(SimpleServerEvent, map) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_simple_server_event(simple_server_event, attrs), to: SimpleServerEventLib

  @spec delete_simple_server_event(SimpleServerEvent) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_simple_server_event(simple_server_event), to: SimpleServerEventLib

  @spec change_simple_server_event(SimpleServerEvent) :: Ecto.Changeset
  defdelegate change_simple_server_event(simple_server_event), to: SimpleServerEventLib

  @spec change_simple_server_event(SimpleServerEvent, map) :: Ecto.Changeset
  defdelegate change_simple_server_event(simple_server_event_type, attrs),
    to: SimpleServerEventLib

  # ------------------------
  # ------------------------ Property types ------------------------
  # ------------------------
  alias Teiserver.Telemetry.{PropertyType, PropertyTypeLib}

  @spec get_or_add_property_type(String.t()) :: non_neg_integer()
  defdelegate get_or_add_property_type(name), to: PropertyTypeLib

  @spec list_property_types() :: [PropertyType]
  defdelegate list_property_types(), to: PropertyTypeLib

  @spec list_property_types(list) :: [PropertyType]
  defdelegate list_property_types(args), to: PropertyTypeLib

  @spec get_property_type!(non_neg_integer) :: PropertyType
  defdelegate get_property_type!(id), to: PropertyTypeLib

  @spec get_property_type!(non_neg_integer, list) :: PropertyType
  defdelegate get_property_type!(id, args), to: PropertyTypeLib

  @spec create_property_type() :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  defdelegate create_property_type(), to: PropertyTypeLib

  @spec create_property_type(map) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  defdelegate create_property_type(attrs), to: PropertyTypeLib

  @spec update_property_type(PropertyType, map) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  defdelegate update_property_type(property_type, attrs), to: PropertyTypeLib

  @spec delete_property_type(PropertyType) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  defdelegate delete_property_type(property_type), to: PropertyTypeLib

  @spec change_property_type(PropertyType) :: Ecto.Changeset
  defdelegate change_property_type(property_type), to: PropertyTypeLib

  @spec change_property_type(PropertyType, map) :: Ecto.Changeset
  defdelegate change_property_type(property_type, attrs), to: PropertyTypeLib

  # ------------------------
  # ------------------------ Anon Events ------------------------
  # ------------------------
  # Complex anon events
  alias Teiserver.Telemetry.{ComplexAnonEvent, ComplexAnonEventLib}

  @spec log_complex_anon_event(String.t(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexAnonEvent}
  defdelegate log_complex_anon_event(hash, event_type_name, value), to: ComplexAnonEventLib

  @spec list_complex_anon_events() :: [ComplexServerEvent]
  defdelegate list_complex_anon_events(), to: ComplexAnonEventLib

  @spec list_complex_anon_events(list) :: [ComplexServerEvent]
  defdelegate list_complex_anon_events(args), to: ComplexAnonEventLib

  @spec get_complex_anon_event!(non_neg_integer) :: ComplexServerEvent
  defdelegate get_complex_anon_event!(id), to: ComplexAnonEventLib

  @spec get_complex_anon_event!(non_neg_integer, list) :: ComplexServerEvent
  defdelegate get_complex_anon_event!(id, args), to: ComplexAnonEventLib

  @spec create_complex_anon_event() :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_anon_event(), to: ComplexAnonEventLib

  @spec create_complex_anon_event(map) :: {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_complex_anon_event(attrs), to: ComplexAnonEventLib

  @spec update_complex_anon_event(ComplexServerEvent, map) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_complex_anon_event(complex_anon_event, attrs), to: ComplexAnonEventLib

  @spec delete_complex_anon_event(ComplexServerEvent) ::
          {:ok, ComplexServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_complex_anon_event(complex_anon_event), to: ComplexAnonEventLib

  @spec change_complex_anon_event(ComplexServerEvent) :: Ecto.Changeset
  defdelegate change_complex_anon_event(complex_anon_event), to: ComplexAnonEventLib

  @spec change_complex_anon_event(ComplexServerEvent, map) :: Ecto.Changeset
  defdelegate change_complex_anon_event(complex_anon_event_type, attrs), to: ComplexAnonEventLib

  # Simple anon events
  alias Teiserver.Telemetry.{SimpleAnonEvent, SimpleAnonEventLib}

  @spec log_simple_anon_event(String.t(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, SimpleAnonEvent}
  defdelegate log_simple_anon_event(hash, event_type_name), to: SimpleAnonEventLib

  @spec list_simple_anon_events() :: [SimpleServerEvent]
  defdelegate list_simple_anon_events(), to: SimpleAnonEventLib

  @spec list_simple_anon_events(list) :: [SimpleServerEvent]
  defdelegate list_simple_anon_events(args), to: SimpleAnonEventLib

  @spec get_simple_anon_event!(non_neg_integer) :: SimpleServerEvent
  defdelegate get_simple_anon_event!(id), to: SimpleAnonEventLib

  @spec get_simple_anon_event!(non_neg_integer, list) :: SimpleServerEvent
  defdelegate get_simple_anon_event!(id, args), to: SimpleAnonEventLib

  @spec create_simple_anon_event() :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_anon_event(), to: SimpleAnonEventLib

  @spec create_simple_anon_event(map) :: {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate create_simple_anon_event(attrs), to: SimpleAnonEventLib

  @spec update_simple_anon_event(SimpleServerEvent, map) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate update_simple_anon_event(simple_anon_event, attrs), to: SimpleAnonEventLib

  @spec delete_simple_anon_event(SimpleServerEvent) ::
          {:ok, SimpleServerEvent} | {:error, Ecto.Changeset}
  defdelegate delete_simple_anon_event(simple_anon_event), to: SimpleAnonEventLib

  @spec change_simple_anon_event(SimpleServerEvent) :: Ecto.Changeset
  defdelegate change_simple_anon_event(simple_anon_event), to: SimpleAnonEventLib

  @spec change_simple_anon_event(SimpleServerEvent, map) :: Ecto.Changeset
  defdelegate change_simple_anon_event(simple_anon_event_type, attrs), to: SimpleAnonEventLib

  # ------------------------
  # ------------------------ Property instances (Anon and User) ------------------------
  # ------------------------
  alias Teiserver.Telemetry.{AnonProperty, AnonPropertyLib}

  @spec log_anon_property(String.t(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, AnonProperty}
  defdelegate log_anon_property(hash, property_type_name, value), to: AnonPropertyLib

  @spec list_anon_properties() :: [ComplexServerProperty]
  defdelegate list_anon_properties(), to: AnonPropertyLib

  @spec list_anon_properties(list) :: [ComplexServerProperty]
  defdelegate list_anon_properties(args), to: AnonPropertyLib

  @spec get_anon_property!(String.t(), String.t() | non_neg_integer()) :: UserProperty.t()
  defdelegate get_anon_property!(hash, property_type_name_or_id), to: AnonPropertyLib

  @spec get_anon_property(String.t(), String.t() | non_neg_integer()) :: UserProperty.t() | nil
  defdelegate get_anon_property(hash, property_type_name_or_id), to: AnonPropertyLib

  @spec create_anon_property() :: {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate create_anon_property(), to: AnonPropertyLib

  @spec create_anon_property(map) :: {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate create_anon_property(attrs), to: AnonPropertyLib

  @spec update_anon_property(ComplexServerProperty, map) ::
          {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate update_anon_property(anon_property, attrs), to: AnonPropertyLib

  @spec delete_anon_property(ComplexServerProperty) ::
          {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate delete_anon_property(anon_property), to: AnonPropertyLib

  @spec change_anon_property(ComplexServerProperty) :: Ecto.Changeset
  defdelegate change_anon_property(anon_property), to: AnonPropertyLib

  @spec change_anon_property(ComplexServerProperty, map) :: Ecto.Changeset
  defdelegate change_anon_property(anon_property_type, attrs), to: AnonPropertyLib

  # User
  alias Teiserver.Telemetry.{UserProperty, UserPropertyLib}

  @spec log_user_property(T.userid(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, UserProperty}
  defdelegate log_user_property(userid, property_type_name, value), to: UserPropertyLib

  @spec list_user_properties() :: [ComplexServerProperty]
  defdelegate list_user_properties(), to: UserPropertyLib

  @spec list_user_properties(list) :: [ComplexServerProperty]
  defdelegate list_user_properties(args), to: UserPropertyLib

  @spec get_user_property!(T.userid(), String.t() | non_neg_integer()) :: UserProperty.t()
  defdelegate get_user_property!(userid, property_type_name_or_id), to: UserPropertyLib

  @spec get_user_property(T.userid(), String.t() | non_neg_integer()) :: UserProperty.t() | nil
  defdelegate get_user_property(userid, property_type_name_or_id), to: UserPropertyLib

  @spec create_user_property() :: {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate create_user_property(), to: UserPropertyLib

  @spec create_user_property(map) :: {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate create_user_property(attrs), to: UserPropertyLib

  @spec update_user_property(ComplexServerProperty, map) ::
          {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate update_user_property(user_property, attrs), to: UserPropertyLib

  @spec delete_user_property(ComplexServerProperty) ::
          {:ok, ComplexServerProperty} | {:error, Ecto.Changeset}
  defdelegate delete_user_property(user_property), to: UserPropertyLib

  @spec change_user_property(ComplexServerProperty) :: Ecto.Changeset
  defdelegate change_user_property(user_property), to: UserPropertyLib

  @spec change_user_property(ComplexServerProperty, map) :: Ecto.Changeset
  defdelegate change_user_property(user_property_type, attrs), to: UserPropertyLib

  alias Teiserver.Telemetry.{Infolog, InfologLib}

  @spec infolog_query(List.t()) :: Ecto.Query.t()
  def infolog_query(args) do
    infolog_query(nil, args)
  end

  @spec infolog_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def infolog_query(id, args) do
    InfologLib.query_infologs()
    |> InfologLib.search(%{id: id})
    |> InfologLib.search(args[:search])
    |> InfologLib.preload(args[:preload])
    |> InfologLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.offset_query(args[:offset])
  end

  @doc """
  Returns the list of infologs.

  ## Examples

      iex> list_infologs()
      [%Infolog{}, ...]

  """
  @spec list_infologs(List.t()) :: List.t()
  def list_infologs(args \\ []) do
    infolog_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 100)
    |> Repo.all()
  end

  @spec count_infologs(List.t()) :: non_neg_integer()
  def count_infologs(args \\ []) do
    infolog_query(args)
    |> Repo.aggregate(:count, :id)
  end

  @spec get_infolog(Integer.t(), List.t()) :: List.t()
  def get_infolog(id, args \\ []) do
    infolog_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a infolog.

  ## Examples

      iex> create_infolog(%{field: value})
      {:ok, %Infolog{}}

      iex> create_infolog(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_infolog(map()) :: {:ok, Infolog.t()} | {:error, Ecto.Changeset.t()}
  def create_infolog(attrs \\ %{}) do
    %Infolog{}
    |> Infolog.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_infolog(Infolog.t()) :: {:ok, Infolog.t()} | {:error, Ecto.Changeset.t()}
  def delete_infolog(%Infolog{} = infolog) do
    Repo.delete(infolog)
  end
end
