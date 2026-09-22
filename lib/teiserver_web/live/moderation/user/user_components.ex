defmodule TeiserverWeb.ModerationLive.UserComponents do
  @moduledoc false
  alias Teiserver.Account.Auth
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User
  alias Teiserver.Moderation.ActionLib

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents,
    only: [simple_form: 1, input_tw: 1, list: 1, table: 1, button: 1]

  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <TeiserverWeb.Moderation.UserComponents.search_form
    :if={assigns[:search]}
    params={@search}
  />

  You will need to implement the following event handlers:

  handle_event("update-search", params, %Socket{} = socket)
  handle_event("validate-search", params, %Socket{} = socket)
  handle_event("reset-search", _params, %Socket{} = socket)
  """
  attr :params, :map, required: true
  attr :changed?, :boolean, default: false

  def search_form(%{params: params} = assigns) do
    form = to_form(params)

    assigns =
      assigns
      |> assign(form: form)

    ~H"""
    <.simple_form
      for={@form}
      phx-change="validate-search"
      phx-submit="update-search"
      id="user-search-form"
    >
      <div class="form-input-grid">
        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:name]}
            label="Name/ID"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:email]}
            label="Email"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:role]}
            label="Role"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:without_role]}
            label="Without role"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:restriction]}
            label="Has restriction"
            options={[
              {"Any user", ""},
              {"Warned", "Warning reminder"},
              {"Boss mode", "Boss"},
              {"Reporting", "Reporting"},
              {"Bridging", "Bridging"},
              {"Renaming", "Renaming"},
              {"Muted", "All chat"},
              {"Playing", "All lobbies"},
              {"Banned", "Login"}
            ]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:order_by]}
            label="Order by"
            options={[
              "Newest first",
              "Oldest first",
              "Alphabetical (A-Z)",
              "Alphabetical (Z-A)",
              "Most recent login first",
              "Oldest login first"
            ]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:page_size]}
            label="Records per page"
            options={[5, 10, 25, 50, 100]}
          />
        </div>
      </div>

      <div class="float-right">
        <div phx-click="reset-search" class="btn-reset-form">
          <Fontawesome.icon icon="rotate-left" style="regular" /> Reset
        </div>
        <button class={["btn btn-primary", not @changed? && "btn-soft"]}>
          <Fontawesome.icon icon="search" style="regular" /> Update results
        </button>
      </div>
    </.simple_form>
    """
  end

  @doc """
  <UserComponents.section_menu
    active="some-link"
    scope={@scope}
  />

  <UserComponents.section_menu
    active="some-link"
    scope={@scope}
  >
    <:left_links>
      <li>Link goes here</li>
    </:left_links>
    <:right_links>
      <li>Link goes here</li>
    </:right_links>
  </UserComponents.section_menu>
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true
  attr :user, User, default: nil
  slot :extra_links, doc: "Slot for extra links for the left side of the menu bar"
  slot :inner_block, doc: "Slot for content for the right side of the menu bar"

  def section_menu(assigns) do
    ~H"""
    <div class="section-menu-bar">
      <ul class="menu menu-horizontal">
        <.section_menu_link
          icon="fa-arrow-left"
          url={~p"/moderation"}
        >
          Moderation
        </.section_menu_link>

        <.section_menu_link
          icon={StylingHelper.icon(:list)}
          url={~p"/moderation/users"}
          active={@active == "list"}
        >
          List
        </.section_menu_link>

        <.section_menu_link
          :if={@user}
          icon={StylingHelper.icon(:show)}
          url={~p"/moderation/users/#{@user.id}"}
          active={@active == "show"}
        >
          Show
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "list"}
          icon={StylingHelper.icon(:list)}
          url={~p"/teiserver/admin/user"}
          active={false}
        >
          Old list
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "action"}
          icon="bolt-lightning"
          url="#"
          active={true}
        >
          Action
        </.section_menu_link>

        {render_slot(@extra_links)}
      </ul>

      <div class="section-menu-bar-inner_block">
        <ul class="menu menu-horizontal">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Moderation.UserComponents.status_icon user={user} />
  """
  attr :user, User, required: true

  def status_icon(%{user: %User{} = user} = assigns) do
    restrictions = user.restrictions || []

    ban_status =
      cond do
        Enum.member?(restrictions, "Permanently banned") -> "banned"
        Enum.member?(restrictions, "Login") -> "suspended"
        true -> ""
      end

    icons =
      [
        if(assigns.user.smurf_of_id != nil,
          do: {"primary", ActionLib.action_icon("Smurf")}
        ),
        if(Enum.member?(user.roles, "Smurfer"),
          do: {"info2", "fa-solid fa-arrows-split-up-and-left"}
        ),
        if(ban_status == "banned",
          do: {"danger2", ActionLib.action_icon("Ban")}
        ),
        if(ban_status == "suspended",
          do: {"danger", ActionLib.action_icon("Suspend")}
        ),
        if(Enum.member?(restrictions, "All chat"),
          do: {"danger", ActionLib.action_icon("Mute")}
        ),
        if(Enum.member?(restrictions, "Warning reminder"),
          do: {"warning", ActionLib.action_icon("Warn")}
        ),
        if(Auth.trusted?(user), do: {"", "fa-solid fa-check"}),
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
  <UserComponents.show_tabset tab={@tab} set="1" />
  """

  attr :tab, :string
  attr :set, :string
  attr :scope, Scope

  def show_tabset(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-border">
      <a
        role="tab"
        class={["tab", @tab == "details" && "tab-active"]}
        phx-click="switch-tab"
        phx-value-tab="details"
        phx-value-tabset={@set}
      >
        Details
      </a>

      <a
        role="tab"
        class={["tab", @tab == "audit" && "tab-active"]}
        phx-click="switch-tab"
        phx-value-tab="audit"
        phx-value-tabset={@set}
      >
        Audit
      </a>

      <a
        role="tab"
        class={["tab", @tab == "actions" && "tab-active"]}
        phx-click="switch-tab"
        phx-value-tab="actions"
        phx-value-tabset={@set}
      >
        Actions
      </a>

      <a
        :if={allow?(@scope, "Server")}
        role="tab"
        class={["tab", @tab == "raw" && "tab-active"]}
        phx-click="switch-tab"
        phx-value-tab="raw"
        phx-value-tabset={@set}
      >
        Raw
      </a>
    </div>
    """
  end

  @doc """
  <UserComponents.show_details user={@user} />
  """
  attr :user, User

  def show_details(assigns) do
    ~H"""
    <.list>
      <:item title="Name">{@user.name}</:item>
      <:item title="Email">{@user.email}</:item>
      <:item title="Roles">
        <div :for={role <- @user.roles} class="badge badge-soft badge-primary mx-1">{role}</div>
      </:item>
      <:item title="Registered">
        {@user.inserted_at && Calendar.strftime(@user.inserted_at, "%Y-%m-%d %H:%M:%S")}
      </:item>
      <:item title="Last login">
        {@user.last_login && Calendar.strftime(@user.last_login, "%Y-%m-%d %H:%M:%S")}
      </:item>
      <:item title="Last played">
        {@user.last_played && Calendar.strftime(@user.last_played, "%Y-%m-%d %H:%M:%S")}
      </:item>
    </.list>
    """
  end

  @doc """
  <UserComponents.show_audit audit_logs={@streams.audit_logs} />
  """
  attr :audit_logs, :list

  def show_audit(assigns) do
    ~H"""
    <.table
      id="audit_logs-table"
      rows={@audit_logs}
      table_class="table-sm table-hover"
      row_click={fn {_id, audit_log} -> JS.navigate(~p"/logging/audit_logs/#{audit_log.id}") end}
    >
      <:col :let={{_id, audit_log}} label="Date">
        {Calendar.strftime(audit_log.inserted_at, "%Y-%m-%d %H:%M:%S")}
      </:col>
      <:col :let={{_id, audit_log}} label="Action">{audit_log.action}</:col>
      <:col :let={{_id, audit_log}} label="User">{audit_log.user_id && audit_log.user.name}</:col>
    </.table>
    """
  end

  @doc """
  <UserComponents.show_actions user={@user} />
  """
  attr :user, User

  def show_actions(assigns) do
    ~H"""
    <div :if={not Enum.member?(@user.roles, "GDPR forgotten")}>
      <h3 class="font-bold text-lg">Links</h3>
      <.link
        navigate={~p"/admin/chat?userid=#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm">
          <Fontawesome.icon icon={Teiserver.Chat.LobbyMessageLib.icon()} style="solid" /> Chat
        </.button>
      </.link>

      <.link
        navigate={~p"/teiserver/admin/users/ratings/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm">
          <Fontawesome.icon icon={Teiserver.Account.RatingLib.icon()} style="solid" /> Ratings
        </.button>
      </.link>

      <.link
        navigate={~p"/teiserver/admin/users/relationships/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm">
          <Fontawesome.icon icon={Teiserver.icon(:relationship)} style="solid" /> Relationships
        </.button>
      </.link>

      <.link
        navigate={~p"/teiserver/admin/matches/user/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm">
          <Fontawesome.icon icon={Teiserver.Battle.MatchLib.icon()} style="solid" /> Matches
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/report/user/#{@user}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm">
          <Fontawesome.icon icon={Teiserver.Moderation.ReportLib.icon()} style="solid" /> Reports
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-soft btn-sm btn-disabled">
          <Fontawesome.icon icon="fa-face-angry" style="solid" /> Smurf search
        </.button>
      </.link>
      <br /><br />

      <h3 class="font-bold text-lg">Edit details</h3>
      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-address-card" style="solid" /> Name
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-envelope" style="solid" /> Email
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-users" style="solid" /> Roles
        </.button>
      </.link>

      <br /><br />
      <h3 class="font-bold text-lg">Actions</h3>
      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-person-drowning" style="solid" /> Reset flood protection
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-shield-alt" style="solid" /> Send password reset email
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-gavel" style="solid" /> Ban
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary btn-disabled">
          <Fontawesome.icon icon="fa-broom" style="solid" /> Reset MFA
        </.button>
      </.link>

      <.link
        navigate={~p"/moderation/users/#{@user.id}/smurf_link"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary">
          <Fontawesome.icon icon="fa-link" style="solid" /> Mark as smurf of
        </.button>
      </.link>

      <.link
        :if={not is_nil(@user.gdpr_forget_after)}
        navigate={~p"/moderation/users/#{@user.id}/clear_gdpr_forget"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary">
          <Fontawesome.icon icon="circle-question" /> Clear GDPR forget
        </.button>
      </.link>

      <.link
        :if={is_nil(@user.gdpr_forget_after)}
        navigate={~p"/moderation/users/#{@user.id}/set_gdpr_forget"}
        phx-click={JS.push_focus()}
      >
        <.button class="m-1 btn btn-primary">
          <Fontawesome.icon icon="question" /> Set GDPR forget
        </.button>
      </.link>
    </div>

    <div :if={Enum.member?(@user.roles, "GDPR forgotten")} class="mt-4">
      This user has been GDPR anonymised, you cannot perform any actions on their account.
    </div>
    """
  end

  @doc """
  <UserComponents.show_raw user={@user} />
  """
  attr :user, User
  attr :cache_user, :map

  def show_raw(assigns) do
    json_user =
      assigns[:user]
      |> Map.drop([
        :__struct__,
        :__meta__,
        :user_configs,
        :smurf_of,
        :user_stat,
        :data,
        :password
      ])
      |> Jason.encode!(pretty: true)

    cache_user_json =
      assigns[:cache_user]
      |> Map.from_struct()
      |> Map.drop([
        :password
      ])
      |> Jason.encode!(pretty: true)

    assigns =
      assigns
      |> assign(json_user: json_user)
      |> assign(cache_user_json: cache_user_json)

    ~H"""
    <div class="flex">
      <div class="flex-1">
        <h4>User JSON struct</h4>
        <textarea name="" id="" rows="40" class="form-control font-mono w-full">{@json_user}</textarea>
      </div>
      <div class="flex-1">
        <h4>Cache user JSON struct</h4>
        <textarea name="" id="" rows="40" class="form-control font-mono w-full">{@cache_user_json}</textarea>
      </div>
    </div>
    """
  end

  @doc """
  <UserComponents.quick_search />
  """
  def quick_search(assigns) do
    ~H"""
    <form action={~p"/moderation/users"} method="GET" class="inline-block">
      <.input_tw
        type="text"
        value=""
        name="name"
        placeholder="Search by id/username"
        class="input input-sm"
        fieldset?={false}
      />
    </form>
    """
  end
end
