defmodule TeiserverWeb.Components.Logging.MatchLogComponents do
  @moduledoc """
  Components for MatchLog pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Logging.MatchLogComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "day_metrics"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/logging/match/day_metrics"}
    >
      Daily metrics
    </.section_menu_button>

    <.section_menu_button
      active={@active == "today"}
      icon="fa-solid fa-waveform"
      bsname={@colour}
      url={~p"/logging/match/day_metrics/today"}
    >
      Today
    </.section_menu_button>

    <.section_menu_button
      active={@active == "graph"}
      icon="fa-solid fa-chart-line-up"
      bsname={@colour}
      url={~p"/logging/match/day_metrics/graph"}
    >
      Graph
    </.section_menu_button>

    <.section_menu_button
      active={@active == "download"}
      icon="fa-solid fa-download"
      bsname={@colour}
      url={~p"/logging/match/export_form"}
    >
      Download
    </.section_menu_button>
    &nbsp;&nbsp;&nbsp;&nbsp;
    <.section_menu_button
      active={@active == "month_metrics"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/logging/match/month_metrics"}
    >
      Monthly metrics
    </.section_menu_button>

    <.section_menu_button
      active={@active == "this_month"}
      icon="fa-solid fa-waveform"
      bsname={@colour}
      url={~p"/logging/match/month_metrics/today"}
    >
      Month to date
    </.section_menu_button>

    <.section_menu_button
      active={@active == "month_graph"}
      icon="fa-solid fa-chart-line-up"
      bsname={@colour}
      url={~p"/logging/match/month_metrics/graph"}
    >
      Graph
    </.section_menu_button>
    """
  end
end
