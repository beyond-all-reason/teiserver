defmodule Barserver.Config.UserConfigTypes.PrivacyConfigs do
  @moduledoc false
  import Barserver.Config, only: [add_user_config_type: 1]

  @spec create() :: :ok
  def create() do
    privacy_levels = ["Only myself", "Friends", "Any player", "Completely public"]

    add_user_config_type(%{
      key: "privacy.Ratings visibility",
      section: "Privacy",
      type: "select",
      opts: [choices: privacy_levels],
      default: "Friends",
      description: "Controls who can see your rating levels on your profile."
    })

    add_user_config_type(%{
      key: "privacy.Match history visibility",
      section: "Privacy",
      type: "select",
      opts: [choices: privacy_levels],
      default: "Friends",
      description: "Controls who can see your previous matches from your profile."
    })

    add_user_config_type(%{
      key: "privacy.Accolade visibility",
      section: "Privacy",
      type: "select",
      opts: [choices: privacy_levels],
      default: "Completely public",
      description: "Controls who can see your accolades from your profile."
    })

    add_user_config_type(%{
      key: "privacy.Achievement visibility",
      section: "Privacy",
      type: "select",
      opts: [choices: privacy_levels],
      default: "Any player",
      description: "Controls who can see your achievements from your profile."
    })

    add_user_config_type(%{
      key: "privacy.Allow followers",
      section: "Privacy",
      type: "boolean",
      default: "false",
      description: "Allows/prevents people from following you."
    })
  end
end
