defmodule TeiserverWeb.Battle.MatchComponents do
  @moduledoc false
  use TeiserverWeb, :component
  alias Teiserver.Battle
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  defp build_download_link(nil), do: nil

  defp build_download_link(game_id) do
    url = Application.get_env(:teiserver, :replay)[:api_url] <> game_id

    with {:ok, response} <- HTTPoison.get(url).body,
         {:ok, json} <- Jason.decode(response) do
      filename =
        json["fileName"]
        |> String.replace(" ", "%20")

      Application.get_env(:teiserver, :replay)[:storage_url] <> filename
    else
      {:error, _} -> nil
    end
  end

  @doc """
  <TeiserverWeb.Battle.MatchComponents.section_menu active={active} bsname={} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  attr :replay, :string, default: nil

  def section_menu(assigns) do
    download_link =
      Battle.get_match(assigns.match_id).game_id
      |> build_download_link()

    assign(assigns, :download_link, download_link)

    ~H"""
    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:list)}
      active={@active == "index"}
      url={~p"/battle"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={Teiserver.Account.RatingLib.icon()}
      active={@active == "ratings"}
      url={~p"/battle/ratings"}
    >
      Ratings
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:chart)}
      active={@active == "progression"}
      url={~p"/battle/progression"}
    >
      Progression
    </.section_menu_button>

    <%= if @match_id do %>
      <.section_menu_button
        bsname={@view_colour}
        icon={StylingHelper.icon(:detail)}
        active={@active == "show"}
        url={~p"/battle/#{@match_id}"}
      >
        Match details
      </.section_menu_button>

      <.section_menu_button
        :if={allow?(@current_user, "Overwatch")}
        bsname={@view_colour}
        icon={StylingHelper.icon(:chat)}
        active={@active == "chat"}
        url={~p"/battle/chat/#{@match_id}"}
      >
        Chat
      </.section_menu_button>
    <% end %>

    <div class="float-end">
      <.section_menu_button
        :if={@download_link != nil}
        bsname={@view_colour}
        icon={StylingHelper.icon(:export)}
        active={false}
        url={@download_link}
      >
        Download Replay
      </.section_menu_button>
    </div>

    <div class="float-end">
      <.section_menu_button
        :if={@replay != nil}
        bsname={@view_colour}
        icon={StylingHelper.icon(:replay)}
        active={false}
        url={@replay}
      >
        Replay
      </.section_menu_button>
    </div>
    """
  end
end
