defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/", TeiserverWeb.General, as: :ts_general do
        pipe_through([:browser, :nomenu_layout])

        get("/code_of_conduct", GeneralController, :code_of_conduct)
        get("/privacy_policy", GeneralController, :gdpr)
        get("/gdpr", GeneralController, :gdpr)
      end

      scope "/teiserver", TeiserverWeb.General, as: :ts_general do
        pipe_through([:browser, :standard_layout, :protected])

        get("/", GeneralController, :index)
      end

      # ts_account_X_path
      scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
        pipe_through([:browser, :standard_layout, :protected])

        get("/relationships", RelationshipsController, :index)
        post("/relationships/find/", RelationshipsController, :find)
        post("/relationships/create/:action/:target", RelationshipsController, :create)
        put("/relationships/update/:action/:target", RelationshipsController, :update)
        delete("/relationships/delete/:action/:target", RelationshipsController, :delete)

        resources("/preferences", PreferencesController,
          only: [:index, :edit, :update, :new, :create]
        )

        get("/", GeneralController, :index)
        get("/customisation_form", GeneralController, :customisation_form)
        get("/customisation_select/:role", GeneralController, :customisation_select)
      end

      scope "/teiserver", TeiserverWeb.Account, as: :ts_account do
        pipe_through([:browser, :standard_layout])

        get("/profile/:id", ProfileController, :show)
        get("/profile", ProfileController, :index)
      end

      # ts_clans_X_path
      scope "/teiserver/clans", TeiserverWeb.Clans, as: :ts_clans do
        pipe_through([:browser, :standard_layout, :protected])

        get("/", ClanController, :index)
        get("/:name", ClanController, :show)
        put("/update/:clan_id", ClanController, :update)

        get("/set_default/:id", ClanController, :set_default)
        post("/create_invite", ClanController, :create_invite)
        delete("/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/respond_to_invite/:clan_id/:response", ClanController, :respond_to_invite)
        delete("/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        put("/promote/:clan_id/:user_id", ClanController, :promote)
        put("/demote/:clan_id/:user_id", ClanController, :demote)
      end

      scope "/teiserver/games", TeiserverWeb.Game, as: :ts_game do
        pipe_through([:browser, :standard_layout, :protected])
        resources("/queues", QueueController)
      end

      scope "/teiserver/battle", TeiserverWeb.Battle, as: :ts_battle do
        pipe_through([:browser, :standard_layout, :protected])

        get("/", GeneralController, :index)
      end

      scope "/teiserver/battle", TeiserverWeb.Battle, as: :ts_battle do
        pipe_through([:browser, :standard_layout, :protected])

        resources("/matches", MatchController, only: [:index, :show, :delete])
      end

      scope "/teiserver/battle", TeiserverWeb.Battle.LobbyLive, as: :ts_battle do
        pipe_through([:browser, :standard_layout, :protected])

        live("/lobbies", Index, :index)
        live("/lobbies/show/:id", Show, :show)
        live("/lobbies/chat/:id", Chat, :chat)
      end

      scope "/teiserver/matchmaking", TeiserverWeb.Matchmaking.QueueLive, as: :ts_game do
        pipe_through([:browser, :standard_layout, :protected])

        live("/queues", Index, :index)
        live("/queues/:id", Show, :show)
      end


      # REPORTING
      scope "/teiserver/reports", TeiserverWeb.Report, as: :ts_reports do
        pipe_through([:browser, :standard_layout, :protected])

        get("/", GeneralController, :index)

        # Server metrics
        get("/server/day_metrics/now", ServerMetricController, :now)
        get("/server/day_metrics/load", ServerMetricController, :load)
        get("/server/day_metrics/today", ServerMetricController, :day_metrics_today)
        get("/server/day_metrics/show/:date", ServerMetricController, :day_metrics_show)
        get("/server/day_metrics/export_form", ServerMetricController, :day_metrics_export_form)
        post("/server/day_metrics/export_post", ServerMetricController, :day_metrics_export_post)
        get("/server/day_metrics/graph", ServerMetricController, :day_metrics_graph)
        post("/server/day_metrics/graph", ServerMetricController, :day_metrics_graph)
        get("/server/day_metrics", ServerMetricController, :day_metrics_list)
        post("/server/day_metrics", ServerMetricController, :day_metrics_list)

        get("/server/month_metrics/today", ServerMetricController, :month_metrics_today)
        get("/server/month_metrics/show/:year/:month", ServerMetricController, :month_metrics_show)
        get("/server/month_metrics/graph", ServerMetricController, :month_metrics_graph)
        post("/server/month_metrics/graph", ServerMetricController, :month_metrics_graph)
        get("/server/month_metrics", ServerMetricController, :month_metrics_list)
        post("/server/month_metrics", ServerMetricController, :month_metrics_list)

        # Match metrics
        get("/match/day_metrics/today", MatchMetricController, :day_metrics_today)
        get("/match/day_metrics/show/:date", MatchMetricController, :day_metrics_show)
        get("/match/day_metrics/graph", MatchMetricController, :day_metrics_graph)
        post("/match/day_metrics/graph", MatchMetricController, :day_metrics_graph)
        get("/match/day_metrics", MatchMetricController, :day_metrics_list)
        post("/match/day_metrics", MatchMetricController, :day_metrics_list)
        get("/match/export_form", MatchMetricController, :export_form)
        post("/match/export_post", MatchMetricController, :export_post)


        get("/match/month_metrics/today", MatchMetricController, :month_metrics_today)
        get("/match/month_metrics/show/:year/:month", MatchMetricController, :month_metrics_show)
        get("/match/month_metrics/graph", MatchMetricController, :month_metrics_graph)
        post("/match/month_metrics/graph", MatchMetricController, :month_metrics_graph)
        get("/match/month_metrics", MatchMetricController, :month_metrics_list)
        post("/match/month_metrics", MatchMetricController, :month_metrics_list)

        # Client events
        get("/client_events/export/form", ClientEventController, :export_form)
        post("/client_events/export/post", ClientEventController, :export_post)
        get("/client_events/summary", ClientEventController, :summary)
        get("/client_events/property/:property_name/detail", ClientEventController, :property_detail)
        get("/client_events/event/:event_name/detail", ClientEventController, :event_detail)

        get("/infolog/download/:id", InfologController, :download)
        resources("/infolog", InfologController, only: [:index, :show, :delete])

        get("/show/:name", ReportController, :show)
        post("/show/:name", ReportController, :show)
      end

      # ts_engine_X_path
      scope "/teiserver/engine", TeiserverWeb.Engine, as: :ts_engine do
        pipe_through([:browser, :standard_layout, :protected])

        resources("/unit", UnitController)
      end

      # API
      scope "/teiserver/api", TeiserverWeb.API do
        pipe_through :api
        post "/login", SessionController, :login
      end

      scope "/teiserver/api", TeiserverWeb.API do
        pipe_through([:token_api])
        post "/battle/create", BattleController, :create
      end

      # ADMIN
      scope "/teiserver/admin", TeiserverWeb.AdminDashLive, as: :ts do
        pipe_through([:browser, :standard_layout, :protected])

        live("/dashboard", Index, :index)
      end

      scope "/teiserver/admin", TeiserverWeb.ClientLive, as: :ts_admin do
        pipe_through([:browser, :standard_layout, :protected])

        live("/client", Index, :index)
        live("/client/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.AgentLive, as: :ts_admin do
        pipe_through([:browser, :standard_layout, :protected])

        live("/agent", Index, :index)
        # live("/agent/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
        pipe_through([:browser, :standard_layout, :protected])

        get("/", GeneralController, :index)
        get("/metrics", GeneralController, :metrics)

        get("/tools", ToolController, :index)
        get("/tools/convert", ToolController, :convert_form)
        post("/tools/convert_post", ToolController, :convert_post)

        post("/clans/create_membership", ClanController, :create_membership)
        delete("/clans/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        delete("/clans/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/clans/promote/:clan_id/:user_id", ClanController, :promote)
        put("/clans/demote/:clan_id/:user_id", ClanController, :demote)
        resources("/clans", ClanController)

        get("/users/rename_form/:id", UserController, :rename_form)
        put("/users/rename_post/:id", UserController, :rename_post)
        get("/users/reset_password/:id", UserController, :reset_password)
        get("/users/relationships/:id", UserController, :relationships)
        get("/users/action/:id/:action", UserController, :perform_action)
        put("/users/action/:id/:action", UserController, :perform_action)
        get("/users/reports/:id/respond", UserController, :respond_form)
        put("/users/reports/:id/respond", UserController, :respond_post)
        get("/users/smurf_search/:id", UserController, :smurf_search)
        get("/users/automod_action_form/:id", UserController, :automod_action_form)
        post("/users/automod_action_post/:id", UserController, :automod_action_post)
        get("/users/full_chat/:id", UserController, :full_chat)
        get("/users/full_chat/:id/:page", UserController, :full_chat)
        get("/users/search", UserController, :index)
        post("/users/set_stat", UserController, :set_stat)
        get("/users/data_search", UserController, :data_search)
        post("/users/data_search", UserController, :data_search)
        post("/users/search", UserController, :search)
        get("/users/applying/:id", UserController, :applying)
        resources("/user", UserController)

        resources("/automod_action", AutomodActionController, only: [:index, :show, :create, :edit, :update])
        put("/automod_action/:id/disable", AutomodActionController, :disable)
        put("/automod_action/:id/enable", AutomodActionController, :enable)

        resources("/badge_types", BadgeTypeController)
        resources("/accolades", AccoladeController, only: [:index, :show, :delete])
        get("/accolades/user/:user_id", AccoladeController, :user_show)

        resources("/matches", MatchController, only: [:index, :show, :delete])
        get("/matches/search", MatchController, :index)
        post("/matches/search", MatchController, :search)
        get("/matches/user/:user_id", MatchController, :user_show)

        resources("/chat", ChatController, only: [:index])
        post("/chat", ChatController, :index)

        resources("/achievements", AchievementController)

        get("/lobbies/:id/chat", LobbyController, :chat)
        get("/lobbies/:id/chat/:page", LobbyController, :chat)
      end
    end
  end
end
