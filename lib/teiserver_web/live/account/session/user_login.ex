defmodule TeiserverWeb.Account.SessionLive.UserLogin do
  @moduledoc false
  alias Phoenix.Flash

  use TeiserverWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="single-block-content">
      <div class="card bg-base-200 shadow-xl">
        <div class="card-body">
          <h1 class="text-4xl font-bold mb-4">
            {gettext("Sign In")}
          </h1>

          <.simple_form
            for={@form}
            id="login_form"
            action={~p"/login"}
            phx-update="ignore"
            class="w-full"
          >
            <.input
              field={@form[:email]}
              type="email"
              label={gettext("Email")}
              autofocus="autofocus"
              tabindex="1"
              required
            />
            <br />

            <.link href={~p"/forgot_password"} class="float-end" tabindex="-1">
              {gettext("Forgot your password?")}
            </.link>
            <.input field={@form[:password]} type="password" label="Password" tabindex="2" required />
            <br />

            <div class="flex">
              <div class="flex-1 px-2">
                <a
                  href={Teiserver.Config.get_site_config_cache("site.Main site link")}
                  class="btn btn-neutral w-full"
                >
                  Main site
                </a>
              </div>
              <div class="flex-1 px-2">
                <.button
                  phx-disable-with={gettext("Signing in...")}
                  class="btn btn-primary w-full"
                  tabindex="40"
                >
                  {gettext("Login")} <span aria-hidden="true">→</span>
                </.button>
              </div>
            </div>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
