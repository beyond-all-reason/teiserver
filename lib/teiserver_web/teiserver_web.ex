defmodule TeiserverWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use TeiserverWeb, :controller
      use TeiserverWeb, :view

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
      import TeiserverWeb.Gettext
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: TeiserverWeb
      import Phoenix.LiveView.Controller
      import Plug.Conn
      import TeiserverWeb.Gettext

      use Breadcrumble

      alias Teiserver.Plugs.AssignPlug

      import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

      alias Bodyguard.Plug.Authorize

      alias TeiserverWeb.Router.Helpers, as: Routes
      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]

      unquote(verified_routes())

      import Teiserver.Account.RecentlyUsedCache,
        only: [remove_recently: 2, insert_recently: 2, insert_recently: 1, get_recently: 1]
    end
  end

  def view do
    quote do
      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      import Teiserver.Helper.StringHelper
      alias Teiserver.Helper.StylingHelper
      import Teiserver.Helper.StylingHelper, only: [colours: 1, colours: 2]

      alias Teiserver.Helper.ColourHelper
      import Teiserver.Helper.ColourHelper, only: [rgba_css: 1, rgba_css: 2]
      import Central.Helpers.InputHelper
      import Central.Helpers.ComponentHelper
      import Teiserver.Helper.TimexHelper

      import Teiserver.Config, only: [get_user_config_cache: 2, get_site_config_cache: 1]

      import TeiserverWeb.ErrorHelpers
      use Gettext, backend: TeiserverWeb.Gettext
      alias TeiserverWeb.Router.Helpers, as: Routes

      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]

      import Teiserver.Helper.NumberHelper,
        only: [normalize: 1, round: 2, c_round: 2, percent: 1, percent: 2]

      import TeiserverWeb.CoreComponents
      import TeiserverWeb.NavComponents
      unquote(verified_routes())

      import Phoenix.LiveView
      import Phoenix.Component
      import Phoenix.LiveView.Helpers

      use Phoenix.View,
        root: "lib/teiserver_web/templates",
        namespace: TeiserverWeb
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

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {TeiserverWeb.Layouts, :app}

      use Breadcrumble
      alias Teiserver.Account.AuthPlug

      import Teiserver.Account.AuthLib,
        only: [allow?: 2, allow_any?: 2, mount_require_all: 2, mount_require_any: 2]

      import Teiserver.Helper.ColourHelper, only: [rgba_css: 1, rgba_css: 2]

      import Teiserver.Helper.NumberHelper,
        only: [normalize: 1, round: 2, c_round: 2, percent: 1, percent: 2]

      import Teiserver.Helper.TimexHelper
      alias Teiserver.Helper.StylingHelper

      import Teiserver.Account.RecentlyUsedCache,
        only: [remove_recently: 2, insert_recently: 2, insert_recently: 1, get_recently: 1]

      defguard is_connected?(socket) when socket.transport_pid != nil
      unquote(verified_routes())
      unquote(view_helpers())
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component
      alias Phoenix.LiveView.JS
      import TeiserverWeb.Gettext

      alias Teiserver.Helper.StylingHelper
      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]

      unquote(verified_routes())
    end
  end

  def queries do
    quote do
      import Ecto.Query, warn: false
      import Teiserver.Helper.QueryHelpers
      alias Ecto.Multi
      alias Teiserver.Repo
    end
  end

  def library do
    quote do
      alias Teiserver.Repo
      import Ecto.Query, warn: false
      alias Ecto.Multi

      import Teiserver.Helper.QueryHelpers
      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      alias Teiserver.Helper.StylingHelper
      alias Teiserver.Data.Types, as: T
    end
  end

  def library_newform do
    quote do
      alias Teiserver.Data.Types, as: T
      alias Teiserver.Repo
      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      alias Teiserver.Helper.{QueryHelpers, StylingHelper}
    end
  end

  def report do
    quote do
      alias Teiserver.Repo
      import Ecto.Query, warn: false
      alias Ecto.Multi

      import Teiserver.Helper.QueryHelpers
      alias Teiserver.Helper.DatePresets
      import Teiserver.Helper.TimexHelper, only: [date_to_str: 2]
      import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
    end
  end

  def startup do
    quote do
      import Teiserver.Account.AuthLib, only: [add_permission_set: 3]

      import Teiserver.Config, only: [add_site_config_type: 1]
      import Teiserver.Logging.AuditLogLib, only: [add_audit_types: 1]
    end
  end

  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Teiserver.Account.AuthLib, only: [allow?: 2, allow_any?: 2]
      import Teiserver.Helper.SchemaHelper
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
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View
      import TeiserverWeb.{CoreComponents, NavComponents}

      import TeiserverWeb.ErrorHelpers
      import TeiserverWeb.Gettext
      alias TeiserverWeb.Router.Helpers, as: Routes
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import TeiserverWeb.{CoreComponents, NavComponents}
      import TeiserverWeb.Gettext
      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS
      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: TeiserverWeb.Endpoint,
        router: TeiserverWeb.Router,
        statics: TeiserverWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
