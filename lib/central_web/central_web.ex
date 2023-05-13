defmodule CentralWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use CentralWeb, :controller
      use CentralWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def static_paths, do: ~w(css js assets webfonts fonts images favicon.ico robots.txt)

  def channel do
    quote do
      use Phoenix.Channel
      import CentralWeb.Gettext
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: CentralWeb
      import Phoenix.LiveView.Controller
      import Plug.Conn
      import CentralWeb.Gettext

      use Breadcrumble

      alias Central.General.AssignPlug

      import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

      alias Bodyguard.Plug.Authorize

      alias CentralWeb.Router.Helpers, as: Routes
      import Central.Account.AuthLib, only: [allow?: 2, allow_any?: 2]

      unquote(verified_routes())

      import Central.Account.RecentlyUsedCache,
        only: [remove_recently: 2, insert_recently: 2, insert_recently: 1, get_recently: 1]
    end
  end

  def view_structure do
    quote do
      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import Central.Helpers.StringHelper
      alias Central.Helpers.StylingHelper
      import Central.Helpers.StylingHelper, only: [colours: 1, colours: 2]

      alias Central.Helpers.ColourHelper
      import Central.Helpers.ColourHelper, only: [rgba_css: 1, rgba_css: 2]
      import Central.Helpers.InputHelper
      import Central.Helpers.ComponentHelper
      import Central.Helpers.TimexHelper

      import Central.Config, only: [get_user_config_cache: 2, get_site_config_cache: 1]

      import CentralWeb.ErrorHelpers
      import CentralWeb.Gettext
      alias CentralWeb.Router.Helpers, as: Routes

      import Central.Account.AuthLib, only: [allow?: 2, allow_any?: 2]

      import Central.Helpers.NumberHelper,
        only: [normalize: 1, round: 2, c_round: 2, percent: 1, percent: 2]

      import CentralWeb.CoreComponents
      unquote(verified_routes())

      import Phoenix.LiveView
      import Phoenix.Component
      import Phoenix.LiveView.Helpers
    end
  end

  def html do
    quote do
      use Phoenix.Component
      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def view do
    quote do
      use CentralWeb, :view_structure

      use Phoenix.View,
        root: "lib/central_web/templates",
        namespace: CentralWeb
    end
  end

  def live_view_structure do
    quote do
      use Phoenix.LiveView,
        layout: {CentralWeb.LayoutView, :standard_live}

      use Breadcrumble
      alias Central.Account.AuthPlug
      import Central.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      alias Central.Communication.NotificationPlug
      unquote(verified_routes())

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use CentralWeb, :live_view_structure
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def library do
    quote do
      alias Central.Repo
      import Ecto.Query, warn: false
      alias Ecto.Multi

      import Central.Helpers.QueryHelpers
      import Central.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      alias Central.Helpers.StylingHelper
    end
  end

  def report do
    quote do
      alias Central.Repo
      import Ecto.Query, warn: false
      alias Ecto.Multi

      import Central.Helpers.QueryHelpers
      import Central.Helpers.ReportHelper
      alias Central.Helpers.DatePresets
      import Central.Helpers.TimexHelper, only: [date_to_str: 2]
      import Central.Helpers.NumberHelper, only: [int_parse: 1]
    end
  end

  def startup do
    quote do
      import Central.Account.AuthLib, only: [add_permission_set: 3]
      import Central.Account.GroupTypeLib, only: [add_group_type: 2]

      import Central.Config, only: [add_user_config_type: 1, add_site_config_type: 1]
      import Teiserver.Logging.AuditLogLib, only: [add_audit_types: 1]
      alias Central.General.QuickAction
    end
  end

  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Central.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      import Central.Helpers.SchemaHelper
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers
      import CentralWeb.LiveHelpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View
      import CentralWeb.CoreComponents

      import CentralWeb.ErrorHelpers
      import CentralWeb.Gettext
      alias CentralWeb.Router.Helpers, as: Routes
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import CentralWeb.CoreComponents
      import CentralWeb.Gettext
      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS
      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: CentralWeb.Endpoint,
        router: CentralWeb.Router,
        statics: CentralWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
