defmodule Teiserver.Account.RoleLib do
  @moduledoc """
  A library with all the hard-coded data regarding user roles.
  """

  # If Role A contains Role B, Role B needs to be listed first
  @raw_role_data [
    # Global
    %{name: "Default", colour: "#666666", icon: "fa-solid fa-user", contains: ~w(), badge: false},
    %{name: "Armada", colour: "#000066", icon: "fa-solid fa-a", contains: ~w(), badge: false},
    %{name: "Cortex", colour: "#660000", icon: "fa-solid fa-c", contains: ~w(), badge: false},
    %{name: "Legion", colour: "#006600", icon: "fa-solid fa-l", contains: ~w(), badge: false},
    %{
      name: "Raptor",
      colour: "#AA6600",
      icon: "fa-solid fa-drumstick",
      contains: ~w(),
      badge: false
    },
    %{
      name: "Scavenger",
      colour: "#660066",
      icon: "fa-solid fa-user-robot",
      contains: ~w(),
      badge: false
    },

    # Property
    %{name: "Trusted", colour: "#FFFFFF", icon: "fa-solid fa-check-square", contains: ~w()},
    %{name: "Bot", colour: "#777777", icon: "fa-solid fa-user-robot", contains: ~w()},
    %{
      name: "Verified",
      colour: "#66AA66",
      icon: "fa-duotone fa-check",
      contains: ~w(),
      badge: false
    },

    # Community team
    %{
      name: "Community team",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ~w(),
      badge: false
    },
    %{
      name: "Mentor",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: false
    },
    %{
      name: "Academy manager",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: false
    },
    %{
      name: "Promo team",
      colour: "#66AA66",
      icon: "fa-duotone fa-thought-bubble",
      contains: ["Community team"],
      badge: false
    },

    # Privileged
    %{name: "VIP", colour: "#AA8833", icon: "fa-duotone fa-sparkles", contains: ~w()},
    %{name: "Streamer", colour: "#660066", icon: "fa-brands fa-twitch", contains: ~w()},
    %{name: "Tournament", colour: "#0000AA", icon: "fa-duotone fa-trophy", contains: ~w()},
    %{
      name: "Caster",
      colour: "#660066",
      icon: "fa-duotone fa-microphone-lines",
      contains: ~w(Streamer Tournament)
    },
    %{name: "Donor", colour: "#0066AA", icon: "fa-duotone fa-euro", contains: ~w()},

    # Contributor/Staff
    %{
      name: "Contributor",
      colour: "#66AA66",
      icon: "fa-duotone fa-code-commit",
      contains: ~w(Trusted)
    },
    %{name: "Engine", colour: "#007700", icon: "fa-duotone fa-engine", contains: ~w(Contributor)},
    %{name: "Mapping", colour: "#007700", icon: "fa-duotone fa-map", contains: ~w(Contributor)},
    %{name: "Gameplay", colour: "#AA0000", icon: "fa-duotone fa-pen-ruler", contains: ~w(Contributor)},
    %{
      name: "Infrastructure",
      colour: "#007700",
      icon: "fa-duotone fa-server",
      contains: ~w(Contributor)
    },
    %{name: "Data export", colour: "#007700", icon: "fa-duotone fa-download", contains: ~w(Contributor)},
    %{name: "Tester", colour: "#00AAAA", icon: "fa-duotone fa-vial", contains: ~w(Contributor)},
    %{
      name: "Core",
      colour: "#007700",
      icon: "fa-duotone fa-code-branch",
      contains: ~w(Contributor)
    },

    # Authority
    %{
      name: "Overwatch",
      colour: "#AA7733",
      icon: "fa-duotone fa-clipboard-list-check",
      contains: ~w()
    },
    %{
      name: "Reviewer",
      colour: "#AA7700",
      icon: "fa-duotone fa-user-magnifying-glass",
      contains: ~w(Overwatch)
    },
    %{name: "Moderator", colour: "#FFAA00", icon: "fa-duotone fa-gavel", contains: ~w(Reviewer)},
    %{
      name: "Admin",
      colour: "#204A88",
      icon: "fa-solid fa-user-tie",
      contains: ~w(Moderator Core)
    },
    %{name: "Server", colour: "#AA2088", icon: "fa-solid fa-user-gear", contains: ~w(Admin)}
  ]

  @role_data @raw_role_data
             |> Enum.reduce(%{}, fn role_def, temp_result ->
               extra_contains =
                 role_def.contains
                 |> Enum.map(fn c -> [c | temp_result[c].contains] end)
                 |> List.flatten()
                 |> Enum.uniq()

               new_def =
                 role_def
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

  @spec role_data(String.t()) :: map()
  def role_data(role_name) do
    @role_data[role_name]
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
    ["Core", "Engine", "Mapping", "Gameplay", "Infrastructure", "Data export", "Tester", "Contributor"]
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
    ~w(Trusted Verified Streamer)
  end

  @spec allowed_role_management(String.t()) :: [String.t()]
  def allowed_role_management("Server") do
    management_roles() ++ allowed_role_management("Admin")
  end

  def allowed_role_management("Admin") do
    staff_roles() ++ privileged_roles() ++ allowed_role_management("Moderator")
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
end
