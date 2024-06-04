defmodule Teiserver.Account.RoleLib do
  @moduledoc """
  A library with all the hard-coded data regarding user roles.
  """

  @role_defaults %{
    badge: false
  }

  # If Role A contains Role B, Role B needs to be listed first
  @raw_role_data [
    # Global
    %{name: "Default", colour: "#666666", icon: "fa-solid fa-user", contains: ~w(), badge: true},
    %{name: "Armada", colour: "#000066", icon: "fa-solid fa-a", contains: ~w(), badge: true},
    %{name: "Cortex", colour: "#660000", icon: "fa-solid fa-c", contains: ~w(), badge: true},
    %{name: "Legion", colour: "#006600", icon: "fa-solid fa-l", contains: ~w(), badge: true},
    %{
      name: "Raptor",
      colour: "#AA6600",
      icon: "fa-solid fa-drumstick",
      contains: ~w(),
      badge: true
    },
    %{
      name: "Scavenger",
      colour: "#660066",
      icon: "fa-solid fa-user-robot",
      contains: ~w(),
      badge: true
    },

    # Property
    %{name: "Trusted", colour: "#FFFFFF", icon: "fa-solid fa-check-square", contains: ~w()},
    %{
      name: "BAR+",
      colour: "#0066AA",
      icon: "fa-solid fa-hexagon-plus",
      contains: ~w(),
      badge: false
    },
    %{name: "Bot", colour: "#777777", icon: "fa-solid fa-user-robot", contains: ~w()},
    %{
      name: "Verified",
      colour: "#66AA66",
      icon: "fa-duotone fa-check",
      contains: ~w()
    },

    # Community team
    %{
      name: "Community team",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ~w(),
      badge: true
    },
    %{
      name: "Mentor",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: true
    },
    %{
      name: "Academy manager",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: true
    },
    %{
      name: "Promo team",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: true
    },

    # Privileged
    %{name: "VIP", colour: "#AA8833", icon: "fa-duotone fa-sparkles", contains: ["BAR+"]},
    %{name: "Streamer", colour: "#660066", icon: "fa-brands fa-twitch", contains: ~w()},
    %{name: "Tournament", colour: "#0000AA", icon: "fa-duotone fa-trophy", contains: ~w()},
    %{
      name: "Caster",
      colour: "#660066",
      icon: "fa-duotone fa-microphone-lines",
      contains: ~w(Streamer Tournament),
      badge: true
    },
    %{name: "Donor", colour: "#0066AA", icon: "fa-duotone fa-euro", contains: ~w(), badge: true},

    # Contributor/Staff
    %{
      name: "Contributor",
      colour: "#66AA66",
      icon: "fa-duotone fa-code-commit",
      contains: ["Trusted", "BAR+"],
      badge: true
    },
    %{name: "Engine", colour: "#007700", icon: "fa-duotone fa-engine", contains: ~w(Contributor)},
    %{name: "Mapping", colour: "#007700", icon: "fa-duotone fa-map", contains: ~w(Contributor)},
    %{
      name: "Gameplay",
      colour: "#AA0000",
      icon: "fa-duotone fa-pen-ruler",
      contains: ~w(Contributor),
      badge: true
    },
    %{
      name: "Infrastructure",
      colour: "#007700",
      icon: "fa-duotone fa-server",
      contains: ~w(Contributor)
    },
    %{
      name: "Data export",
      colour: "#007700",
      icon: "fa-duotone fa-download",
      contains: ~w(Contributor)
    },
    %{
      name: "Tester",
      colour: "#00AAAA",
      icon: "fa-duotone fa-vial",
      contains: ~w(Contributor),
      badge: true
    },
    %{
      name: "Core",
      colour: "#007700",
      icon: "fa-duotone fa-code-branch",
      contains: ~w(Contributor),
      badge: true
    },

    # Authority
    %{
      name: "Overwatch",
      colour: "#AA7733",
      icon: "fa-duotone fa-clipboard-list-check",
      contains: ["BAR+"]
    },
    %{
      name: "Reviewer",
      colour: "#AA7700",
      icon: "fa-duotone fa-user-magnifying-glass",
      contains: ~w(Overwatch)
    },
    %{
      name: "Moderator",
      colour: "#FFAA00",
      icon: "fa-duotone fa-gavel",
      contains: ~w(Reviewer),
      badge: true
    },
    %{
      name: "Admin",
      colour: "#204A88",
      icon: "fa-solid fa-user-tie",
      contains: ~w(Moderator Core),
      badge: true
    },
    %{
      name: "Server",
      colour: "#AA2088",
      icon: "fa-solid fa-user-gear",
      contains: ~w(Admin),
      badge: true
    }
  ]

  @role_data @raw_role_data
             |> Enum.reduce(%{}, fn role_def, temp_result ->
               extra_contains =
                 role_def.contains
                 |> Enum.map(fn c -> [c | temp_result[c].contains] end)
                 |> List.flatten()
                 |> Enum.uniq()

               new_def =
                 @role_defaults
                 |> Map.merge(role_def)
                 |> Map.merge(%{
                   contains: extra_contains
                 })

               Map.put(temp_result, new_def.name, new_def)
             end)
             |> Map.new()

  @spec all_role_names() :: list()
  def all_role_names() do
    Map.keys(@role_data)
  end

  @spec role_data() :: map()
  def role_data() do
    @role_data
  end

  @spec role_data(String.t()) :: map() | nil
  def role_data(role_name) do
    Map.get(@role_data, role_name)
  end

  @spec role_data!(String.t()) :: map()
  def role_data!(role_name) do
    r = @role_data[role_name]
    if r, do: r, else: raise("No role by name #{role_name}")
  end

  @spec global_roles :: [String.t()]
  def global_roles() do
    ~w(Default Armada Cortex Raptor Scavenger)
  end

  @spec management_roles :: [String.t()]
  def management_roles() do
    ~w(Server Admin)
  end

  @spec moderation_roles :: [String.t()]
  def moderation_roles() do
    ~w(Moderator Reviewer Overwatch)
  end

  @spec staff_roles :: [String.t()]
  def staff_roles() do
    [
      "Core",
      "Engine",
      "Mapping",
      "Gameplay",
      "Infrastructure",
      "Data export",
      "Tester",
      "Contributor"
    ]
  end

  @spec community_roles :: [String.t()]
  def community_roles() do
    ["Mentor", "Academy manager", "Promo team", "Community team"]
  end

  @spec privileged_roles :: [String.t()]
  def privileged_roles() do
    ~w(Bot VIP Caster Donor Tournament)
  end

  @spec property_roles :: [String.t()]
  def property_roles() do
    ["Trusted", "BAR+", "Verified", "Streamer"]
  end

  @spec allowed_role_management(String.t()) :: [String.t()]
  def allowed_role_management("Server") do
    management_roles() ++ allowed_role_management("Admin")
  end

  def allowed_role_management("Admin") do
    staff_roles() ++ community_roles() ++ privileged_roles() ++ allowed_role_management("Moderator")
  end

  def allowed_role_management("Moderator") do
    global_roles() ++ moderation_roles() ++ property_roles()
  end

  def allowed_role_management(_) do
    []
  end

  @spec roles_with_permissions() :: [String.t()]
  def roles_with_permissions() do
    management_roles() ++
      moderation_roles() ++ staff_roles() ++ privileged_roles() ++ property_roles()
  end

  def calculate_permissions(roles) do
    roles
    |> Enum.map(fn role_name ->
      role_def = role_data(role_name)
      [role_name | role_def.contains]
    end)
    |> List.flatten()
    |> Enum.uniq()
  end
end
