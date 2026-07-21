defmodule Teiserver.Account.RoleLib do
  @moduledoc """
  A library with all the hard-coded data regarding user roles.

  If you update this file, please run:
  mix teiserver.update_user_permissions

  to update permissions in the database of each user
  """

  alias Teiserver.Account.Role

  @role_data [
               # Property
               %Role{
                 name: "Trusted",
                 colour: "#FFFFFF",
                 icon: "fa-solid fa-check-square",
                 contains: []
               },
               %Role{
                 name: "Bot",
                 colour: "#777777",
                 icon: "fa-solid fa-user-robot",
                 contains: []
               },
               %Role{
                 name: "Verified",
                 colour: "#66AA66",
                 icon: "fa-solid fa-check",
                 contains: []
               },
               %Role{
                 name: "Tournament winner",
                 colour: "#AA8833",
                 icon: "fa-solid fa-trophy",
                 contains: []
               },

               # Privileged
               %Role{
                 name: "VIP",
                 colour: "#AA8833",
                 icon: "fa-solid fa-sparkles",
                 contains: ~w(Trusted)
               },
               %Role{
                 name: "Caster",
                 colour: "#660066",
                 icon: "fa-solid fa-microphone-lines",
                 contains: [],
                 badge: true
               },

               # Contributor/Staff
               %Role{
                 name: "Contributor",
                 colour: "#66AA66",
                 icon: "fa-solid fa-code-commit",
                 contains: ["Trusted", "BAR+", "VIP"],
                 badge: true
               },

               # Authority
               %Role{
                 name: "Overwatch",
                 colour: "#AA7733",
                 icon: "fa-solid fa-clipboard-list-check",
                 contains: ["BAR+", "Trusted"]
               },
               %Role{
                 name: "Reviewer",
                 colour: "#AA7700",
                 icon: "fa-solid fa-user-magnifying-glass",
                 contains: ["Overwatch", "BAR+", "Trusted"]
               },
               %Role{
                 name: "Event Organizer",
                 colour: "#00AA88",
                 icon: "fa-solid fa-bullhorn",
                 contains: [],
                 badge: true
               },
               %Role{
                 name: "Moderator",
                 colour: "#FFAA00",
                 icon: "fa-solid fa-gavel",
                 contains: ["Reviewer", "Contributor", "Overwatch", "BAR+", "VIP", "Trusted"],
                 badge: true
               },
               %Role{
                 name: "Senior moderator",
                 colour: "#FF7700",
                 icon: "fa-solid fa-scale-unbalanced",
                 contains: [
                   "Moderator",
                   "Reviewer",
                   "Contributor",
                   "Overwatch",
                   "BAR+",
                   "VIP",
                   "Trusted"
                 ],
                 badge: true
               },
               %Role{
                 name: "Admin",
                 colour: "#204A88",
                 icon: "fa-solid fa-user-tie",
                 contains: [
                   "Senior moderator",
                   "Moderator",
                   "Reviewer",
                   "Contributor",
                   "Overwatch",
                   "BAR+",
                   "VIP",
                   "Trusted"
                 ],
                 badge: true
               },
               %Role{
                 name: "Server",
                 colour: "#AA2088",
                 icon: "fa-solid fa-user-gear",
                 contains: [
                   "Admin",
                   "Senior moderator",
                   "Moderator",
                   "Reviewer",
                   "Contributor",
                   "Overwatch",
                   "BAR+",
                   "VIP",
                   "Trusted"
                 ],
                 badge: true
               },

               # Not manually used
               %Role{
                 name: "GDPR forgotten",
                 colour: "#000000",
                 icon: "fa-solid fa-question-mark",
                 contains: [],
                 badge: false
               },
               %Role{
                 name: "Smurfer",
                 colour: "#000000",
                 icon: "fa-solid fa-question-mark",
                 contains: [],
                 badge: false
               }
             ]
             |> Map.new(fn r -> {r.name, r} end)

  @spec all_role_names() :: [String.t()]
  def all_role_names do
    Map.keys(@role_data)
  end

  @spec role_data() :: %{String.t() => Role.t()}
  def role_data, do: @role_data

  @spec role_data(String.t()) :: Role.t() | nil
  def role_data(role_name) do
    Map.get(@role_data, role_name)
  end

  @spec management_roles :: [String.t()]
  def management_roles do
    ["Server", "Admin"]
  end

  @spec moderation_roles :: [String.t()]
  def moderation_roles do
    ["Senior moderator", "Moderator", "Reviewer", "Overwatch"]
  end

  @spec staff_roles :: [String.t()]
  def staff_roles do
    [
      "Contributor"
    ]
  end

  @spec community_roles :: [String.t()]
  def community_roles do
    [
      "Event Organizer"
    ]
  end

  @spec privileged_roles :: [String.t()]
  def privileged_roles do
    ~w(Bot VIP Caster)
  end

  @spec property_roles :: [String.t()]
  def property_roles do
    ["Trusted", "BAR+", "Verified", "Tournament winner"]
  end

  @spec allowed_role_management(String.t()) :: [String.t()]
  def allowed_role_management("Server") do
    management_roles() ++ allowed_role_management("Admin")
  end

  def allowed_role_management("Admin") do
    staff_roles() ++
      community_roles() ++
      privileged_roles() ++ moderation_roles() ++ allowed_role_management("Senior moderator")
  end

  def allowed_role_management("Senior moderator") do
    allowed_role_management("Moderator") ++ ["Overwatch"]
  end

  def allowed_role_management("Moderator") do
    property_roles()
  end

  def allowed_role_management(_role) do
    []
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
