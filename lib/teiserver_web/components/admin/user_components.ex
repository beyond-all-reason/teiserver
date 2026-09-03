defmodule TeiserverWeb.Components.Admin.UserComponents do
  @moduledoc """
  Components for User pages
  """
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1, tw_section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Admin.UserComponents.section_menu active={active} colour={} current_user={@current_user} />
  """
  attr :current_user, User, required: true
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <div class="row">
      <div class="col-md-9">
        <.section_menu_button
          active={@active == "client_admin"}
          icon={Teiserver.Account.ClientLib.icon()}
          bsname={@colour}
          url={~p"/teiserver/admin/client"}
        >
          Client admin
        </.section_menu_button>

        <.section_menu_button
          active={@active == "list"}
          icon={Teiserver.Helper.StylingHelper.icon(:list)}
          bsname={@colour}
          url={~p"/teiserver/admin/user"}
        >
          List
        </.section_menu_button>

        <.section_menu_button
          active={@active == "advanced_search"}
          icon={Teiserver.Helper.StylingHelper.icon(:search)}
          bsname={@colour}
          url={~p"/teiserver/admin/user?search=true"}
        >
          Advanced search
        </.section_menu_button>

        <.section_menu_button
          :if={allow?(@current_user, "admin")}
          active={@active == "data_search"}
          icon="fa-solid fa-print-magnifying-glass"
          bsname={@colour}
          url={~p"/teiserver/admin/users/data_search"}
        >
          Data search
        </.section_menu_button>

        <%= if @active == "show" do %>
          <.section_menu_button
            active={@active == "show"}
            icon={Teiserver.Helper.StylingHelper.icon(:detail)}
            bsname={@colour}
            url="#"
          >
            Show
          </.section_menu_button>
        <% end %>

        <%= if @active == "edit" do %>
          <.section_menu_button
            active={@active == "edit"}
            icon={Teiserver.Helper.StylingHelper.icon(:edit)}
            bsname={@colour}
            url="#"
          >
            Edit
          </.section_menu_button>
        <% end %>

        <%= if @active == "smurf" do %>
          <.section_menu_button
            active={@active == "smurf"}
            icon="fa-solid fa-face-angry"
            bsname={@colour}
            url="#"
          >
            Smurf search
          </.section_menu_button>
        <% end %>

        <%= if @active == "smurf_merge_form" do %>
          <.section_menu_button
            active={@active == "smurf_merge_form"}
            icon="fa-solid fa-merge"
            bsname={@colour}
            url="#"
          >
            Smurf merge
          </.section_menu_button>
        <% end %>

        <%= if @active == "ratings" do %>
          <.section_menu_button
            active={@active == "ratings"}
            icon={"fa-solid #{Teiserver.Account.RatingLib.icon()}"}
            bsname={@colour}
            url="#"
          >
            Ratings
          </.section_menu_button>
        <% end %>

        <%= if @active == "ratings_form" do %>
          <.section_menu_button
            active={@active == "ratings_form"}
            icon={"fa-solid #{Teiserver.Account.RatingLib.icon()}"}
            bsname={@colour}
            url="#"
          >
            Ratings form
          </.section_menu_button>
        <% end %>

        <%= if @active == "moderation" do %>
          <.section_menu_button
            active={@active == "moderation"}
            icon={"fa-solid #{Teiserver.Moderation.icon()}"}
            bsname={@colour}
            url="#"
          >
            Moderation
          </.section_menu_button>
        <% end %>
      </div>

      <div class="col-md-3">
        <form action={~p"/teiserver/admin/user"} method="get" class="">
          <div class="input-group">
            <% input_opts = [
              autofocus: if(not Enum.member?(["edit"], @active), do: "autofocus")
            ] %>
            <input
              type="text"
              name="s"
              id="quick_search"
              value={assigns[:quick_search]}
              placeholder="Quick search"
              class="form-control"
              style="width: 150px; display: inline-block;"
              {input_opts}
            /> &nbsp;
            <input
              type="submit"
              value="Search"
              class={"btn btn-#{@colour} float-end"}
              style="margin-top: 0px;"
            />
          </div>
        </form>
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Components.Admin.UserComponents.tw_section_menu
    active="some-link"
    scope={@scope}
  />
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true
  attr :search_value, :string
  attr :search_autofocus, :boolean, default: false

  def tw_section_menu(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-box float-end">
      <div class="tab">
        <form action={~p"/teiserver/admin/user"} method="get" class="">
          <div class="input-group">
            <% input_opts = [
              autofocus: @search_autofocus
            ] %>
            <input
              type="text"
              name="s"
              id="quick_search"
              value={assigns[:search_value]}
              placeholder="Quick search"
              class="input"
              style="width: 150px; display: inline-block;"
              {input_opts}
            /> &nbsp;
            <input
              type="submit"
              value="Search"
              class="btn btn-primary float-end"
              style="margin-top: 0px;"
            />
          </div>
        </form>
      </div>
    </div>

    <div role="tablist" class="tabs tabs-box">
      <.tw_section_menu_button
        active={@active == "client_admin"}
        icon={Teiserver.Account.ClientLib.icon()}
        url={~p"/teiserver/admin/client"}
      >
        Client admin
      </.tw_section_menu_button>

      <.tw_section_menu_button
        active={@active == "list"}
        icon={Teiserver.Helper.StylingHelper.icon(:list)}
        url={~p"/teiserver/admin/user"}
      >
        List
      </.tw_section_menu_button>

      <.tw_section_menu_button
        active={@active == "search"}
        icon={Teiserver.Helper.StylingHelper.icon(:search)}
        url={~p"/teiserver/admin/user?search=true"}
      >
        Search
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={allow?(@scope, "admin")}
        active={@active == "data_search"}
        icon="fa-solid fa-magnifying-glass-chart"
        url={~p"/teiserver/admin/users/data_search"}
      >
        Data search
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "show"}
        active={true}
        icon={Teiserver.Helper.StylingHelper.icon(:detail)}
        url="#"
      >
        Show
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "edit"}
        active={true}
        icon={Teiserver.Helper.StylingHelper.icon(:edit)}
        url="#"
      >
        Edit
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "smurf"}
        active={true}
        icon="fa-solid fa-face-angry"
        url="#"
      >
        Smurf search
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "smurf_merge_form"}
        active={true}
        icon="fa-solid fa-merge"
        url="#"
      >
        Smurf merge
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "ratings"}
        active={true}
        icon={"fa-solid #{Teiserver.Account.RatingLib.icon()}"}
        url="#"
      >
        Ratings
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "ratings_form"}
        active={true}
        icon={"fa-solid #{Teiserver.Account.RatingLib.icon()}"}
        url="#"
      >
        Ratings form
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "moderation"}
        active={true}
        icon={"fa-solid #{Teiserver.Moderation.icon()}"}
        url="#"
      >
        Moderation
      </.tw_section_menu_button>
    </div>
    """
  end
end
