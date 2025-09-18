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
        if(Enum.member?(user.roles, "Smurfer"), do: {"info2", "fa-solid fa-split"}),
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
          do: {"info", "fa-solid fa-square-question"}
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
    <div :if={not Enum.empty?(@recents)} class="nav-item dropdown mx-2">
      <a
        class="dropdown-toggle dropdown-toggle-icon-only"
        href="#"
        data-bs-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
        id="user-recents-link"
      >
        <i class="fa-solid fa-clock fa-fw fa-lg"></i>
      </a>
      <div
        class="dropdown-menu dropdown-menu-end"
        aria-labelledby="user-recents-link"
        style="min-width: 300px; max-width: 500px;"
      >
        <span class="dropdown-header" style="font-weight: bold;">
          Recent items
        </span>

        <a :for={r <- @recents} class="dropdown-item" href={r.url}>
          <Fontawesome.icon icon={r.type_icon} style="regular" css_style={"color: #{r.type_colour}"} />

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
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.UserComponents.account_dropdown current_user={@current_user} />
  """
  attr :current_user, :map, required: true

  def account_dropdown(assigns) do
    ~H"""
    <div class="nav-item dropdown mx-2">
      <a
        class="dropdown-toggle dropdown-toggle-icon-only"
        href="#"
        data-bs-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
        id="user-dropdown-link"
      >
        <i class="fa-solid fa-user fa-fw fa-lg"></i>
      </a>
      <div
        class="dropdown-menu dropdown-menu-end"
        aria-labelledby="user-dropdown-link"
        style="min-width: 300px; max-width: 500px;"
      >
        <a class="dropdown-item" href={~p"/profile"}>
          <i class={"fa-fw #{Teiserver.Account.icon()}"}></i> &nbsp;
          Account
        </a>

        <hr style="margin: 0;" />

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
      </div>
    </div>
    """
  end
end
