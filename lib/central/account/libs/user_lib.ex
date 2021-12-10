defmodule Central.Account.UserLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Account.User
  alias Central.Account.GroupLib

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:primary)

  @spec icon :: String.t()
  def icon(), do: "far fa-user"

  @spec make_favourite(User.t()) :: Map.t()
  def make_favourite(user) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: user.id,
      item_type: "central_user",
      item_colour: user.colour,
      item_icon: user.icon,
      item_label: "#{user.name} - #{user.email}",
      url: "/admin/users/#{user.id}"
    }
  end

  def has_access(target_user_id, conn) when is_integer(target_user_id) do
    if allow?(conn.permissions, "admin.admin.full") do
      {true, nil}
    else
      query =
        from target_users in User,
          where: target_users.id == ^target_user_id,
          select: target_users.admin_group_id

      group_id = Repo.one(query)

      has_access(%{group_id: group_id, admin_group_id: group_id}, conn)
    end
  end

  def has_access(nil, _user), do: {false, :not_found}

  def has_access(target_user, conn) do
    if allow?(conn, "admin.admin.full") do
      {true, nil}
    else
      result = GroupLib.access?(conn, target_user.admin_group_id)

      case result do
        true -> {true, nil}
        false -> {false, :no_access}
      end
    end
  end

  def has_access!(target_user, conn) do
    {result, _} = has_access(target_user, conn)
    result
  end
end
