defmodule TeiserverWeb.Telemetry.TelemetryComponents do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.Telemetry.TelemetryComponents.sub_menu active={active} view_colour={@view_colour} current_user={@current_user} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Telemetry.TelemetryLib.icon()}
        active={@active == "telemetry"}
        url={~p"/telemetry"}
      >
        Telemetry home
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Engine")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.InfologLib.icon()}
        active={@active == "infologs"}
        url={~p"/telemetry/infolog"}
      >
        Infologs
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Server")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.PropertyTypeLib.icon()}
        active={@active == "properties"}
        url={~p"/telemetry/properties/summary"}>
        Properties
      </.sub_menu_button>


      <.sub_menu_button
        :if={String.contains?(@active, "_client_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.SimpleClientEventLib.icon()}
        active={@active == "simple_client_events"}
        url={~p"/telemetry/simple_client_events/summary"}>
        Simple client events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_client_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.ComplexClientEventLib.icon()}
        active={@active == "complex_client_events"}
        url={~p"/telemetry/complex_client_events/summary"}>
        Complex client events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_server_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.SimpleServerEventLib.icon()}
        active={@active == "simple_server_events"}
        url={~p"/telemetry/simple_server_events/summary"}>
        Simple server events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_server_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.ComplexServerEventLib.icon()}
        active={@active == "complex_server_events"}
        url={~p"/telemetry/complex_server_events/summary"}>
        Complex client events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_match_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.SimpleMatchEventLib.icon()}
        active={@active == "simple_match_events"}
        url={~p"/telemetry/simple_match_events/summary"}>
        Simple match events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_match_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.ComplexMatchEventLib.icon()}
        active={@active == "complex_match_events"}
        url={~p"/telemetry/complex_match_events/summary"}>
        Complex match events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_lobby_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.SimpleLobbyEventLib.icon()}
        active={@active == "simple_lobby_events"}
        url={~p"/telemetry/simple_lobby_events/summary"}>
        Simple lobby events
      </.sub_menu_button>

      <.sub_menu_button
        :if={String.contains?(@active, "_lobby_events")}
        bsname={@view_colour}
        icon={Teiserver.Telemetry.ComplexLobbyEventLib.icon()}
        active={@active == "complex_lobby_events"}
        url={~p"/telemetry/complex_lobby_events/summary"}>
        Complex lobby events
      </.sub_menu_button>
    </div>
    """
  end
end
