defmodule Teiserver.Config.UserConfigTypes.ProfileConfigs do
  @moduledoc """
  Cache and setup for profile configuration
  """

  use Supervisor

  import Teiserver.Config, only: [add_user_config_type: 1]

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- create() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      {ConCache, [name: :config_user_type_store, ttl_check_interval: false]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec create() :: :ok
  def create() do
    add_user_config_type(%{
      key: "general.Colour scheme",
      section: "Interface",
      type: "select",
      visible: true,
      permissions: [],
      opts: [choices: ["Site default", "Light", "Dark"]],
      default: "Site default",
      description: "The colour scheme used by the site."
    })

    add_user_config_type(%{
      key: "general.Rate limit",
      section: "General",
      type: "integer",
      visible: false,
      permissions: ["admin.dev.developer"],
      description: "Page rate limit per minute",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "general.Screen size",
      section: "General",
      type: "string",
      visible: false,
      permissions: ["admin.dev.developer"],
      description:
        "Last recorded screen size of the user, used for sizing certain windows accordingly",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "general.Advanced configs",
      section: "General",
      type: "boolean",
      visible: false,
      permissions: ["admin.dev.developer"],
      description:
        "Changes the default behaviour of showing or hiding advanced options on the forms supporting them.",
      opts: [],
      default: false
    })

    # Need to get the timezones
    zones = Tzdata.zone_list()

    add_user_config_type(%{
      key: "general.Timezone",
      section: "General",
      type: "select",
      visible: true,
      permissions: [],
      description: "The timezone you are present in for conversion of timestamps.",
      opts: [
        choices: zones
      ],
      default: Application.get_env(:teiserver, Teiserver.Config)[:defaults].tz
    })

    add_user_config_type(%{
      key: "general.Language",
      section: "General",
      type: "select",
      visible: false,
      permissions: [],
      description: "Language used on the site (currently only English).",
      opts: [
        choices: ~w(English)
      ],
      default: false
    })

    add_user_config_type(%{
      key: "teiserver.Show flag",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["account"],
      description:
        "When checked the flag associated with your IP will be displayed. If unchecked your flag will be blank. This will take effect next time you login with your client.",
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Discord notifications",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["account"],
      description:
        "When checked you will receive discord messages from the Teiserver bridge bot for various in-lobby events. When disabled you will receive no notifications even if the others are enabled.",
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Exited the queue",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["account"],
      description: "You will be messaged when you move from being in the queue to being a player",
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Game start",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["account"],
      description: "You will be messaged when a lobby you are a player in starts",
      default: true
    })
  end
end
