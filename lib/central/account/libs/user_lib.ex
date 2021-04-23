defmodule Central.Account.UserLib do
  use CentralWeb, :library

  alias Bamboo.Email
  alias Central.Account
  alias Central.Account.User
  alias Central.Account.GroupLib

  def colours(), do: Central.Helpers.StylingHelper.colours(:primary)
  def icon(), do: "far fa-user"

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

  def reset_password_request(user, code \\ nil) do
    # We need this to enable recreating the email if we know it
    # should exist but at the same time we don't want
    # callers of this function to have to create the code
    # themselves
    code =
      if code do
        code
      else
        {:ok, code} =
          Account.create_code(%{
            value: UUID.uuid4(),
            purpose: "reset_password",
            expires: Timex.now() |> Timex.shift(hours: 24),
            user_id: user.id
          })

        code
      end

    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    url = "https://#{host}/password_reset/#{code.value}"

    html_body = """
    <p>A request for a password reset has been requested for you. To reset your password follow the link below. If you did not request this reset please ignore the email.</p>

    <p><a href="#{url}">#{url}</a></p>
    """

    text_body = """
    A request for a password reset has been requested for you. To reset your password follow the link below. If you did not request this reset please ignore the email.

    #{url}
    """

    Email.new_email()
    |> Email.to({user.name, user.email})
    |> Email.from(
      {Application.get_env(:central, Central.Mailer)[:noreply_name],
       Central.Mailer.noreply_address()}
    )
    |> Email.subject(Application.get_env(:central, Central)[:site_title])
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
  end
end
