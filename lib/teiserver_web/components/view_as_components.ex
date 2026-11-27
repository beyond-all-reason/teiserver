defmodule TeiserverWeb.ViewAsComponents do
  @moduledoc """
  Shared UI for the "view as" feature, see `Teiserver.Account.ViewAs`.

  The styling lives next to the markup (rather than in app.css) because the
  banner is rendered from both the Bootstrap and the Tailwind root layouts,
  which load different stylesheets.
  """
  alias Teiserver.Account.User
  alias Teiserver.Account.ViewAs

  use TeiserverWeb, :component

  @doc """
  Fixed banner shown while viewing as another user. Renders nothing otherwise.
  """
  attr :real_user, :any, default: nil
  attr :current_user, :any, default: nil

  def banner(assigns) do
    ~H"""
    <div :if={@real_user && @current_user} id="view-as-banner" class="view-as-banner">
      <style>
        .view-as-banner {
          position: fixed;
          bottom: 0;
          left: 0;
          right: 0;
          z-index: 1100;
          background: #b45309;
          color: #fff;
          padding: 8px 12px;
          text-align: center;
          box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.4);
        }
        body {
          padding-bottom: 52px;
        }
        .view-as-stop {
          margin-left: 12px;
          padding: 4px 14px;
          background: #fff;
          color: #92400e;
          border: 2px solid #fff;
          border-radius: 6px;
          font-weight: 700;
          cursor: pointer;
          transition: background 0.15s, color 0.15s, transform 0.15s, box-shadow 0.15s;
        }
        .view-as-stop:hover,
        .view-as-stop:focus-visible {
          background: #92400e;
          color: #fff;
          transform: translateY(-1px);
          box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
        }
        .view-as-stop:active {
          transform: translateY(0);
          box-shadow: none;
        }
      </style>
      Viewing as <strong>{@current_user.name}</strong>
      (logged in as {@real_user.name}).
      <.form for={%{}} action={~p"/view_as"} method="delete" style="display:inline">
        <button type="submit" class="view-as-stop">✕ Stop viewing as</button>
      </.form>
    </div>
    """
  end

  @doc """
  "View site as this user" button. Shown enabled when allowed, disabled with an
  explanation when the actor is an admin who may not view as `target`, and not
  at all for everyone else.

  `actor` must be the real logged in user (`@real_user || @current_user`).
  While a "view as" session is active (`viewing_as?`) the button is disabled and
  asks the user to stop the current session first, so sessions can't be chained.
  `style` selects the markup flavour of the surrounding UI.
  """
  attr :actor, :any, required: true
  attr :target, :any, required: true
  attr :viewing_as?, :boolean, default: false
  attr :style, :atom, values: [:daisy, :bootstrap], required: true

  def button(assigns) do
    assigns =
      assigns
      |> assign(
        :visible?,
        ViewAs.can_use?(assigns.actor) and match?(%User{}, assigns.target)
      )
      |> assign(
        :allowed?,
        not assigns.viewing_as? and ViewAs.can_view_as?(assigns.actor, assigns.target)
      )
      |> assign(:reason, reason(assigns))

    ~H"""
    <%= if @visible? do %>
      <%= if @allowed? do %>
        <.form
          for={%{}}
          action={~p"/view_as/#{@target.id}"}
          method="post"
          class={if @style == :daisy, do: "inline me-4", else: "mb-3"}
        >
          <button type="submit" class={button_class(@style)}>View site as this user</button>
        </.form>
      <% else %>
        <span
          class={if @style == :daisy, do: "tooltip tooltip-bottom me-4", else: "d-inline-block mb-3"}
          data-tip={@reason}
          title={@reason}
        >
          <button
            type="button"
            class={button_class(@style)}
            disabled
            style={if @style == :bootstrap, do: "pointer-events: none;"}
          >
            View site as this user
          </button>
        </span>
      <% end %>
    <% end %>
    """
  end

  defp reason(%{viewing_as?: true}),
    do:
      "Stop viewing as the current user first (use \"Stop viewing as\" in the bar at the bottom)."

  defp reason(%{actor: actor, target: target}), do: ViewAs.denial_reason(actor, target)

  defp button_class(:daisy), do: "btn btn-sm btn-warning btn-soft"
  defp button_class(:bootstrap), do: "btn btn-outline-warning"
end
