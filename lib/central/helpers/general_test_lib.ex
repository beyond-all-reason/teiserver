defmodule Central.Helpers.GeneralTestLib do
  import Phoenix.ConnTest, only: [build_conn: 0, post: 3]

  import Ecto.Query
  alias Central.Repo
  import Phoenix.ChannelTest
  # use Phoenix.ConnTest

  @endpoint CentralWeb.Endpoint

  alias Central.Account.AuthLib

  alias Central.Account
  alias Central.Account.User
  alias Central.Account.Group
  # alias CentralWeb.General.GroupLib
  alias Central.Account.GroupCacheLib
  # alias CentralWeb.General.GroupType
  # alias Central.Account.GroupMembership

  # alias CentralWeb.General.CombinatorLib

  alias CentralWeb.UserSocket

  alias Central.Account.Guardian

  # def make_combos(data), do: CombinatorLib.make_combos(data)

  # import CentralWeb.ACL.Authorisation

  def user_fixture(), do: make_user(%{"permissions" => []})

  def make_user(params \\ %{}) do
    permissions =
      (params["permissions"] || [])
      |> AuthLib.split_permissions()

    {:ok, u} =
      Account.create_user(%{
        "name" => params["name"] || "Test",
        "email" => params["email"] || "email@email#{:rand.uniform(999_999_999_999)}",
        "colour" => params["colour"] || "#00AA00",
        "icon" => params["icon"] || "far fa-user",
        "permissions" => permissions,
        "password" => params["password"] || "password",
        "password_confirmation" => params["password"] || "password",
        "admin_group_id" => params["admin_group_id"] || nil,
        "data" => params["data"] || %{}
      })

    u
  end

  def make_account_group(name, super_group_id \\ nil, data \\ %{}, params \\ %{}) do
    {:ok, g} =
      Account.create_group(%{
        "name" => name,
        "colour" => params["colour"] || "#AA0000",
        "icon" => params["icon"] || "far fa-info",
        "active" => params["active"] || true,
        "group_type" => params["group_type"] || nil,
        "data" => data,
        "see_group" => params["see_group"] || false,
        "see_members" => params["see_members"] || true,
        "invite_members" => params["invite_members"] || true,
        "self_add_members" => params["self_add_members"] || false,
        "super_group_id" => super_group_id
      })

    if super_group_id do
      GroupCacheLib.update_caches(g)
      Account.get_group!(g.id)
    else
      g
    end
  end

  def make_account_group_membership(group_id, user_id, data) do
    {:ok, gm} =
      Account.create_group_membership(%{
        "group_id" => group_id,
        "user_id" => user_id,
        "admin" => data["admin"] || false
      })

    gm
  end

  def seeded?() do
    r = Repo.one(from g in Group, where: g.name == "unrelated group")
    r != nil
  end

  def seed() do
    parent_group = make_account_group("parent group", nil)
    main_group = make_account_group("main group", parent_group.id)
    child_group = make_account_group("child group", main_group.id)

    cousin_group =
      make_account_group("cousin group", parent_group.id, %{}, %{"see_group" => true})

    unrelated_group =
      make_account_group("unrelated group", nil, %{}, %{
        "see_group" => true,
        "self_add_members" => true
      })

    groups = [
      main_group,
      child_group,
      parent_group,
      cousin_group,
      unrelated_group
    ]

    users =
      groups
      |> Enum.map(fn g ->
        gname = String.replace(g.name, " group", "")

        make_user(%{
          "name" => "#{gname} user",
          "email" => "#{gname}@#{gname}.com",
          "admin_group_id" => g.id
        })
      end)

    [
      users: users,
      groups: groups
    ]
    |> Central.Logging.LoggingTestLib.seed()
  end

  def login(conn, email) do
    conn
    |> post("/login", %{"user" => %{email: email, password: "password"}})
  end

  def data_setup(flags \\ []) do
    parent_group = Repo.one(from u in Group, where: u.name == "parent group")
    child_group = Repo.one(from u in Group, where: u.name == "child group")
    main_group = Repo.one(from u in Group, where: u.name == "main group")

    user =
      if :user in flags do
        make_user(%{
          "name" => "Current user",
          "email" => "current_user@current_user.com",
          "admin_group_id" => main_group.id,
          "permissions" => []
        })
      end

    {:ok,
     main_group: main_group, child_group: child_group, parent_group: parent_group, user: user}
  end

  # Used for those that need to create additional connections
  def new_conn(nil), do: login(build_conn(), "")

  def new_conn(user) do
    {:ok, jwt, _} = Guardian.encode_and_sign(user)
    {:ok, user, _claims} = Guardian.resource_from_token(jwt)

    login(build_conn(), user.email)
  end

  # @spec general_setup(list, ) :: tuple
  def conn_setup(permissions \\ [], flags \\ []) do
    {:ok, data} = data_setup(flags)

    parent_group = data[:parent_group]
    child_group = data[:child_group]
    main_group = data[:main_group]
    r = :rand.uniform(999_999_999)

    {user, jwt} =
      unless :no_user in flags do
        user =
          make_user(%{
            "name" => "Current user",
            "email" => "current_user#{r}@current_user#{r}.com",
            "admin_group_id" => main_group.id,
            "permissions" => permissions
          })

        # Now add the user to the main group
        make_account_group_membership(main_group.id, user.id, %{"admin" => true})

        # Tokens
        {:ok, jwt, _} = Guardian.encode_and_sign(user)
        {:ok, user, _claims} = Guardian.resource_from_token(jwt)
        {user, jwt}
      else
        {nil, nil}
      end

    # Connection and socket stuff
    # conn = build_conn()
    # |> Guardian.Plug.sign_in(user, %{some: "claim"})
    # |> Guardian.Plug.remember_me(user)

    conn =
      if :no_login in flags or :no_user in flags do
        # build_conn()
        login(build_conn(), "")
      else
        login(build_conn(), user.email)
      end

    child_user =
      if flags[:child_user] do
        Repo.one(from u in User, where: u.name == "child user")
      end

    parent_user =
      if flags[:parent_user] do
        Repo.one(from u in User, where: u.name == "parent user")
      end

    socket =
      if flags[:socket] do
        case connect(UserSocket, %{"token" => jwt}) do
          {:ok, socket} ->
            socket

          _e ->
            throw("Error connecting to socket in test_lib")
        end
      end

    {:ok,
     main_group: main_group,
     child_group: child_group,
     parent_group: parent_group,
     r: r,
     user: user,
     jwt: jwt,
     child_user: child_user,
     parent_user: parent_user,
     conn: conn,
     user_token: jwt,
     socket: socket}
  end
end
