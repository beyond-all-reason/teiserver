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
      contains: [],
      edit_permission: "Moderator",
      group: :privileged
    },
    %Role{
      name: "Bot",
      colour: "#777777",
      icon: "fa-solid fa-robot",
      contains: [],
      edit_permission: "Admin",
      group: :system
    },

    # Common
    %Role{
      name: "Verified",
      colour: "#66AA66",
      icon: "fa-solid fa-check",
      contains: [],
      edit_permission: "Moderator",
      group: :common
    },
    %Role{
      name: "Tournament winner",
      colour: "#AA8833",
      icon: "fa-solid fa-trophy",
      contains: [],
      edit_permission: "Admin",
      group: :common
    },
    %Role{
      name: "Caster",
      colour: "#660066",
      icon: "fa-solid fa-microphone-lines",
      contains: [],
      badge: true,
      edit_permission: "Admin",
      group: :common
    },

    # Privileged
    %Role{
      name: "VIP",
      colour: "#AA8833",
      icon: "fa-solid fa-champagne-glasses",
      contains: ~w(Trusted),
      edit_permission: "Admin",
      group: :privileged
    },
    %Role{
      name: "Event Organizer",
      colour: "#00AA88",
      icon: "fa-solid fa-bullhorn",
      contains: [],
      badge: true,
      edit_permission: "Admin",
      group: :privileged
    },

    # Contributor/Staff
    %Role{
      name: "Contributor",
      colour: "#66AA66",
      icon: "fa-solid fa-code-commit",
      contains: ["Trusted", "BAR+", "VIP", "Staff"],
      badge: true,
      edit_permission: "Admin",
      group: :staff
    },

    # Moderation
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
        "Trusted",
        "Staff"
      ],
      badge: true,
      edit_permission: "Admin",
      group: :moderation
    },
    %Role{
      name: "Moderator",
      colour: "#FFAA00",
      icon: "fa-solid fa-gavel",
      contains: [
        "Reviewer",
        "Contributor",
        "Overwatch",
        "BAR+",
        "VIP",
        "Trusted",
        "Staff"
      ],
      badge: true,
      edit_permission: "Senior moderator",
      group: :moderation
    },
    %Role{
      name: "Reviewer",
      colour: "#AA7700",
      icon: "fa-solid fa-magnifying-glass",
      contains: ["Overwatch", "BAR+", "Trusted"],
      edit_permission: "Senior moderator",
      group: :moderation
    },
    %Role{
      name: "Overwatch",
      colour: "#AA7733",
      icon: "fa-solid fa-user-secret",
      contains: ["BAR+", "Trusted", "Staff"],
      edit_permission: "Senior moderator",
      group: :moderation
    },

    # Admin
    %Role{
      name: "Server",
      colour: "#AA2088",
      icon: "fa-solid fa-gear",
      contains: [
        "Admin",
        "Senior moderator",
        "Moderator",
        "Reviewer",
        "Contributor",
        "Overwatch",
        "BAR+",
        "VIP",
        "Trusted",
        "Staff"
      ],
      badge: true,
      edit_permission: "Server",
      group: :management
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
        "Trusted",
        "Staff"
      ],
      badge: true,
      edit_permission: "Admin",
      group: :management
    },

    # Not manually used
    %Role{
      name: "Staff",
      colour: "#FFFFFF",
      icon: "fa-solid fa-user-tie",
      contains: ["VIP", "Trusted"],
      description:
        "Contributors, Overwatch and others who perform services for the BAR org in some capacity.",
      edit_permission: "Server",
      group: :hidden
    },
    %Role{
      name: "GDPR forgotten",
      colour: "#000000",
      icon: "fa-solid fa-question-mark",
      contains: [],
      badge: false,
      edit_permission: "Server",
      group: :hidden
    },
    %Role{
      name: "Smurfer",
      colour: "#000000",
      icon: "fa-solid fa-question-mark",
      contains: [],
      badge: false,
      edit_permission: "Server",
      group: :hidden
    }
  ]

  @spec all_role_names() :: [String.t()]
  def all_role_names do
    Enum.map(@role_data, & &1.name)
  end

  @spec role_data() :: %{String.t() => Role.t()}
  def role_data, do: Map.new(@role_data, fn r -> {r.name, r} end)

  @spec role_data(String.t()) :: Role.t() | nil
  def role_data(role_name) do
    Map.get(role_data(), role_name)
  end

  def grouped_role_data do
    @role_data
    |> Enum.group_by(& &1.group)
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
