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
    %{name: "Raptor", colour: "#AA6600", icon: "fa-solid fa-drumstick", contains: ~w(), badge: false},
    %{name: "Scavenger", colour: "#660066", icon: "fa-solid fa-user-robot", contains: ~w(), badge: false},

    # Property
    %{name: "Trusted", colour: "#000000", icon: "fa-duotone fa-check", contains: ~w()},
    %{name: "Bot", colour: "#777777", icon: "fa-solid fa-user-robot", contains: ~w()},
    %{name: "Verified", colour: "#66AA66", icon: "fa-duotone fa-check", contains: ~w(), badge: false},

    # Authority
    %{name: "Overwatch", colour: "#AA7733", icon: "fa-duotone fa-clipboard-list-check", contains: ~w()},
    %{name: "Reviewer", colour: "#AA7700", icon: "fa-duotone fa-user-magnifying-glass", contains: ~w(Overwatch)},
    %{name: "Moderator", colour: "#FFAA00", icon: "fa-duotone fa-gavel", contains: ~w(Reviewer)},
    %{name: "Admin", colour: "#204A88", icon: "fa-solid fa-user-tie", contains: ~w(Moderator)},
    %{name: "Server", colour: "#AA2088", icon: "fa-solid fa-user-gear", contains: ~w(Admin)},

    # Staff
    %{name: "Tester", colour: "#00AAAA", icon: "fa-duotone fa-vial", contains: ~w()},
    %{name: "GDT", colour: "#AA0000", icon: "fa-duotone fa-pen-ruler", contains: ~w()},
    %{name: "Contributor", colour: "#00AA66", icon: "fa-duotone fa-code-commit", contains: ~w(Trusted)},
    %{name: "Core", colour: "#008800", icon: "fa-duotone fa-code-branch", contains: ~w(Contributor)},

    # Privileged
    %{name: "VIP", colour: "#AA8833", icon: "fa-duotone fa-sparkles", contains: ~w()},
    %{name: "Streamer", colour: "#0066AA", icon: "fa-brands fa-twitch", contains: ~w()},
    %{name: "Tournament", colour: "#0000AA", icon: "fa-duotone fa-trophy", contains: ~w()},
    %{name: "Caster", colour: "#660066", icon: "fa-duotone fa-microphone-lines", contains: ~w(Streamer Tournament)},
    %{name: "Donor", colour: "#0066AA", icon: "fa-duotone fa-euro", contains: ~w()},
  ]

  @role_data @raw_role_data
    |> Enum.reduce(%{}, fn (role_def, temp_result) ->
      extra_contains = role_def.contains
        |> Enum.map(fn c -> [c | temp_result[c].contains] end)
        |> List.flatten
        |> Enum.uniq

      new_def = role_def
        |> Map.merge(%{
          contains: extra_contains
        })

      Map.put(temp_result, new_def.name, new_def)
    end)
    |> Map.new()

  @spec role_data() :: map()
  def role_data() do
    @role_data
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
    ~w(Core Contributor GDT Tester)
  end

  @spec privileged_roles :: [String.t()]
  def privileged_roles() do
    ~w(VIP Caster Donor Tournament Trusted)
  end

  @spec property_roles :: [String.t()]
  def property_roles() do
    ~w(Bot Verified Streamer)
  end

  @spec allowed_role_management(String.t()) :: [String.t()]
  def allowed_role_management("Server") do
    global_roles() ++ management_roles() ++ moderation_roles() ++ staff_roles() ++ privileged_roles() ++ property_roles()
  end

  def allowed_role_management("Admin") do
    global_roles() ++ moderation_roles() ++ staff_roles() ++ privileged_roles() ++ property_roles()
  end

  def allowed_role_management("Moderator") do
    global_roles() ++ moderation_roles() ++ privileged_roles() ++ property_roles()
  end

  def allowed_role_management(_) do
    []
  end

  @spec roles_with_permissions() :: [String.t()]
  def roles_with_permissions() do
    management_roles() ++ moderation_roles() ++ staff_roles() ++ privileged_roles() ++ property_roles()
  end

  @spec role_def(String.t()) :: nil | {String.t(), String.t()}
  def role_def("Default"), do: {"#666666", "fa-solid fa-user"}
  def role_def("Armada"), do: {"#000066", "fa-solid fa-a"}
  def role_def("Cortex"), do: {"#660000", "fa-solid fa-c"}
  def role_def("Legion"), do: {"#006600", "fa-solid fa-l"}
  def role_def("Raptor"), do: {"#AA6600", "fa-solid fa-drumstick"}
  def role_def("Scavenger"), do: {"#660066", "fa-solid fa-user-robot"}

  def role_def("Admin"), do: {"#CE5C00", "fa-duotone fa-user-circle"}
  def role_def("Moderator"), do: {"#FFAA00", "fa-duotone fa-gavel"}
  def role_def("Reviewer"), do: {"#AA7700", "fa-duotone fa-user-magnifying-glass"}
  def role_def("Overwatch"), do: {"#AA7733", "fa-duotone fa-clipboard-list-check"}
  def role_def("Core team"), do: {"#008800", "fa-duotone fa-code-branch"}
  def role_def("GDT"), do: {"#AA0000", "fa-duotone fa-pen-ruler"}
  def role_def("VIP"), do: {"#AA8833", "fa-duotone fa-sparkles"}
  def role_def("Contributor"), do: {"#00AA66", "fa-duotone fa-code-commit"}
  def role_def("Tournament player"), do: {"#0000AA", "fa-duotone fa-trophy"}

  def role_def("Caster"), do: {"#660066", "fa-duotone fa-microphone-lines"}
  def role_def("Donor"), do: {"#0066AA", "fa-duotone fa-euro"}
  def role_def("Streamer"), do: {"#0066AA", "fa-brands fa-twitch"}

  def role_def(_), do: nil
end
