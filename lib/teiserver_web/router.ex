defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/teiserver", TeiserverWeb.Lobby, as: :ts_lobby do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
      end

      scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
      end

      scope "/teiserver", TeiserverWeb.BattleLive, as: :ts do
        pipe_through([:browser, :admin_layout, :protected])

        live("/battle", Index, :index)
        live("/battle/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        resources("/client", ClientController)

        resources("/user", UserController)
        post("/user/reset_password/:id", UserController, :reset_password)
      end

      # scope "/teiserver", TeiserverWeb.AdminLive, as: :ts do
      #   pipe_through [:browser, :admin_layout, :protected]

      #   live "/admin", Index, :index
      #   live "/admin/new", Index, :new
      #   live "/admin/:id/edit", Index, :edit

      #   live "/admin/:id", Show, :show
      #   live "/admin/:id/show/edit", Show, :edit
      # end
    end
  end
end
