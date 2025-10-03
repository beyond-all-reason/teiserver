defmodule TeiserverWeb.UserComponents do
  @moduledoc false
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import TeiserverWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: TeiserverWeb.Endpoint,
    router: TeiserverWeb.Router,
    statics: TeiserverWeb.static_paths()

  @doc """
  <TeiserverWeb.UserComponents.status_icon user={user} />
  """
  def status_icon(%{user: %{data: user_data} = user} = assigns) do
    restrictions = user_data["restrictions"] || []

    ban_status =
      cond do
        Enum.member?(restrictions, "Permanently banned") -> "banned"
        Enum.member?(restrictions, "Login") -> "suspended"
        true -> ""
      end

    icons =
      [
        if(assigns.user.smurf_of_id != nil,
          do: {"primary", Teiserver.Moderation.ActionLib.action_icon("Smurf")}
        ),
        if(Enum.member?(user.roles, "Smurfer"),
          do: {"info2", "fa-solid fa-arrows-split-up-and-left"}
        ),
        if(ban_status == "banned",
          do: {"danger2", Teiserver.Moderation.ActionLib.action_icon("Ban")}
        ),
        if(ban_status == "suspended",
          do: {"danger", Teiserver.Moderation.ActionLib.action_icon("Suspend")}
        ),
        if(Enum.member?(restrictions, "All chat"),
          do: {"danger", Teiserver.Moderation.ActionLib.action_icon("Mute")}
        ),
        if(Enum.member?(restrictions, "Warning reminder"),
          do: {"warning", Teiserver.Moderation.ActionLib.action_icon("Warn")}
        ),
        if(Enum.member?(user.roles, "Trusted"), do: {"", "fa-solid fa-check"}),
        if(not Enum.member?(user.roles, "Verified"),
          do: {"info", "fa-solid fa-user-secret"}
        )
      ]
      |> Enum.reject(&(&1 == nil))

    status_icon_list(%{icons: icons})
  end

  defp status_icon_list(assigns) do
    ~H"""
    <div :for={{colour, icon} <- @icons} class="d-inline-block">
      <i class={"fa-fw text-#{colour} #{icon}"}></i>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.UserComponents.recents_dropdown current_user={@current_user} />
  """
  attr :current_user, :map, required: true

  def recents_dropdown(assigns) do
    recents =
      assigns[:current_user]
      |> Teiserver.Account.RecentlyUsedCache.get_recently()
      |> Enum.take(15)

    assigns =
      assigns
      |> assign(recents: recents)

    ~H"""
    <li :if={not Enum.empty?(@recents)} class="nav-item dropdown">
      <a
        class="nav-link dropdown-toggle"
        href="#"
        data-bs-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
        id="user-recents-link"
      >
        <i class="fa-solid fa-clock fa-fw"></i>
      </a>
      <ul
        class="dropdown-menu dropdown-menu-end"
        aria-labelledby="user-recents-link"
        style="min-width: 300px; max-width: 500px;"
      >
        <li><span class="dropdown-header" style="font-weight: bold;">Recent items</span></li>
        <li :for={r <- @recents}>
          <a class="dropdown-item" href={r.url}>
            <Fontawesome.icon
              icon={r.type_icon}
              style="regular"
              css_style={"color: #{r.type_colour}"}
            />

            <%= if r.item_icon do %>
              <Fontawesome.icon
                icon={r.item_icon}
                style="regular"
                css_style={"color: #{r.item_colour}"}
              />
            <% else %>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <% end %>
            &nbsp; {r.item_label}
          </a>
        </li>
      </ul>
    </li>
    """
  end

  @doc """
  <TeiserverWeb.UserComponents.account_dropdown current_user={@current_user} />
  """
  attr :current_user, :map, required: true

  def account_dropdown(assigns) do
    ~H"""
    <li class="nav-item dropdown">
      <a
        class="nav-link dropdown-toggle"
        href="#"
        data-bs-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
        id="user-dropdown-link"
      >
        <i class="fa-solid fa-user fa-fw"></i>
      </a>
      <ul
        class="dropdown-menu dropdown-menu-end"
        aria-labelledby="user-dropdown-link"
        style="min-width: 300px; max-width: 500px;"
      >
        <li>
          <a class="dropdown-item" href={~p"/profile"}>
            <i class={"fa-fw #{Teiserver.Account.icon()}"}></i> &nbsp;
            Profile
          </a>
        </li>
        <li>
          <form action={~p"/logout"} method="post" class="link" id="signout-form" style="margin: 0;">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

            <a
              class="dropdown-item"
              data-submit="parent"
              href="#"
              rel="nofollow"
              onclick="$('#signout-form').submit();"
              id="signout-link"
            >
              <i class="fa-solid fa-sign-out fa-fw"></i> &nbsp;
              Sign out {@current_user.name}
            </a>
          </form>
        </li>
      </ul>
    </li>
    """
  end
end
