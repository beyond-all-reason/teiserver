defmodule Teiserver.Account.RoleLib do
  @moduledoc """
  A library with all the hard-coded data regarding user roles.
  """

  @raw_role_data %{
    # Global
    "Default" => %{colour: "#666666", icon: "fa-solid fa-user", contains: ~w(), badge: false},
    "Armada" => %{colour: "#000066", icon: "fa-solid fa-a", contains: ~w(), badge: false},
    "Cortex" => %{colour: "#660000", icon: "fa-solid fa-c", contains: ~w(), badge: false},
    "Legion" => %{colour: "#006600", icon: "fa-solid fa-l", contains: ~w(), badge: false},
    "Raptor" => %{colour: "#AA6600", icon: "fa-solid fa-drumstick", contains: ~w(), badge: false},
    "Scavenger" => %{colour: "#660066", icon: "fa-solid fa-user-robot", contains: ~w(), badge: false},

    # Authority
    "Bot" => %{colour: "#777777", icon: "fa-solid fa-user-robot", contains: ~w()},
    "Server" => %{colour: "#AA2088", icon: "fa-solid fa-user-gear", contains: ~w(Admin)},
    "Admin" => %{colour: "#204A88", icon: "fa-solid fa-user-tie", contains: ~w(Moderator)},
    "Moderator" => %{colour: "#FFAA00", icon: "fa-duotone fa-gavel", contains: ~w(Reviewer)},
    "Reviewer" => %{colour: "#AA7700", icon: "fa-duotone fa-user-magnifying-glass", contains: ~w(Overwatch)},
    "Overwatch" => %{colour: "#AA7733", icon: "fa-duotone fa-clipboard-list-check", contains: ~w()},

    # Staff
    "Core" => %{colour: "#008800", icon: "fa-duotone fa-code-branch", contains: ~w(Contributor)},
    "Contributor" => %{colour: "#00AA66", icon: "fa-duotone fa-code-commit", contains: ~w(Trusted)},
    "GDT" => %{colour: "#AA0000", icon: "fa-duotone fa-pen-ruler", contains: ~w()},
    "Tester" => %{colour: "#00AAAA", icon: "fa-duotone fa-vial", contains: ~w()},

    # Privileged
    "VIP" => %{colour: "#AA8833", icon: "fa-duotone fa-sparkles", contains: ~w()},
    "Caster" => %{colour: "#660066", icon: "fa-duotone fa-microphone-lines", contains: ~w(Streamer Tournament)},
    "Donor" => %{colour: "#0066AA", icon: "fa-duotone fa-euro", contains: ~w()},
    "Streamer" => %{colour: "#0066AA", icon: "fa-brands fa-twitch", contains: ~w()},
    "Tournament" => %{colour: "#0000AA", icon: "fa-duotone fa-trophy", contains: ~w()},
    "Trusted" => %{colour: "#000000", icon: "fa-duotone fa-check", contains: ~w()},
    "Verified" => %{colour: "#66AA66", icon: "fa-duotone fa-check", contains: ~w(), badge: false},
  }

  # Given a role name it returns the list of roles (recursively) it contains
  @spec build_contains_map(String.t()) :: [String.t()]
  defp build_contains_map(name) do
    @raw_role_data[name]
      |> Map.get(:contains, [])
      |> Enum.map(fn r -> build_contains_map(name) end)
  end

  @role_data @raw_role_data
    |> Map.new(fn {name, role} ->
      role = Map.merge(role, %{
        contains: build_contains_map(name)
      })
    end)

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
