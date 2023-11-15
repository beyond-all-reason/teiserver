defmodule TeiserverWeb.PollingComponents do
  @moduledoc false
  use TeiserverWeb, :component
  alias Teiserver.Helper.TimexHelper
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.PollingComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil
  attr :current_user, :map, required: true
  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Polling.SurveyLib.icon()}
        active={@active == "surveys"}
        url={~p"/polling/surveys"}
      >
        Surveys
      </.sub_menu_button>
    </div>
    """
  end
end
