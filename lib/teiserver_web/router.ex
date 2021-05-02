defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/", TeiserverWeb.Lobby, as: :ts_lobby do
        pipe_through([:browser, :blank_layout])

        get("/gdpr", GeneralController, :gdpr)
        get("/privacy_policy", GeneralController, :gdpr)
      end

      scope "/teiserver", TeiserverWeb.Lobby, as: :ts_lobby do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
      end

      # ts_account_X_path
      scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
        pipe_through([:browser, :admin_layout, :protected])

        get("/relationships", RelationshipsController, :index)
        post("/relationships/find/", RelationshipsController, :find)
        post("/relationships/create/:action/:target", RelationshipsController, :create)
        put("/relationships/update/:action/:target", RelationshipsController, :update)
        delete("/relationships/delete/:action/:target", RelationshipsController, :delete)

        resources("/preferences", PreferencesController,
          only: [:index, :edit, :update, :new, :create]
        )

        get("/", GeneralController, :index)
      end

      # ts_clans_X_path
      scope "/teiserver/clans", TeiserverWeb.Clans, as: :ts_clans do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", ClanController, :index)
        get("/:name", ClanController, :show)

        get("/set_default/:id", ClanController, :set_default)
        post("/create_invite", ClanController, :create_invite)
        delete("/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/respond_to_invite/:clan_id/:response", ClanController, :respond_to_invite)
        delete("/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        put("/promote/:clan_id/:user_id", ClanController, :promote)
        put("/demote/:clan_id/:user_id", ClanController, :demote)
      end

      scope "/teiserver/games", TeiserverWeb.Game, as: :ts_game do
        resources("/tournaments", TournamentController)
      end

      scope "/teiserver", TeiserverWeb.BattleLive, as: :ts do
        pipe_through([:browser, :admin_layout, :protected])

        live("/battle", Index, :index)
        live("/battle/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.ClientLive, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        live("/client", Index, :index)
        live("/client/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)

        get("/tools", ToolController, :index)
        get("/tools/convert", ToolController, :convert_form)
        post("/tools/convert_post", ToolController, :convert_post)
        get("/tools/agent_start", ToolController, :agent_start)

        post("/clans/create_membership", ClanController, :create_membership)
        delete("/clans/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        delete("/clans/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/clans/promote/:clan_id/:user_id", ClanController, :promote)
        put("/clans/demote/:clan_id/:user_id", ClanController, :demote)
        resources("/clans", ClanController)

        resources("/parties", PartyController)

        resources("/queues", QueueController)

        # resources("/tournaments", TournamentController)

        post("/user/reset_password/:id", UserController, :reset_password)
        put("/user/action/:id/:action", UserController, :perform_action)
        get("/user/reports/:id/respond", UserController, :respond_form)
        put("/user/reports/:id/respond", UserController, :respond_post)
        get("/users/search", UserController, :index)
        post("/users/search", UserController, :search)
        resources("/user", UserController)
      end
    end
  end
end
