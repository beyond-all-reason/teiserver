defmodule CentralWeb.Router do
  use CentralWeb, :router

  pipeline :dev_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Central.Dev,
      action: :dev_auth,
      user: {Central.Account.AuthLib, :current_user}
  end

  pipeline :logging_live_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Central.Logging.LiveLib,
      action: :live,
      user: {Central.Account.AuthLib, :current_user}
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Central.Account.DefaultsPlug)
    plug(Central.Logging.LoggingPlug)
    plug(Central.Account.AuthPipeline)
    plug(Central.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Central.Communication.NotificationPlug)
  end

  pipeline :admin_layout do
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:put_layout, {CentralWeb.LayoutView, "admin.html"})
  end

  pipeline :standard_layout do
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:put_layout, {CentralWeb.LayoutView, "standard.html"})
  end

  pipeline :standard_live_layout do
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:put_layout, {CentralWeb.LayoutView, :standard_live})
  end

  pipeline :nomenu_layout do
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:put_layout, {CentralWeb.LayoutView, "nomenu.html"})
  end

  pipeline :empty_layout do
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:put_layout, {CentralWeb.LayoutView, "empty.html"})
  end

  pipeline :protected do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :token_api do
    plug(:accepts, ["json"])
    plug(:put_secure_browser_headers)
    plug(Central.Logging.LoggingPlug)
    plug(Central.Account.AuthPipeline)
    plug(Central.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :protected_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Central.Logging.LoggingPlug)
    plug(Central.Account.AuthPipeline)
    plug(Central.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  scope "/", CentralWeb.General, as: :general do
    pipe_through([:browser, :nomenu_layout])

    get("/recache", PageController, :recache)
    get("/browser_info", PageController, :browser_info)
    get("/", PageController, :index)
    get("/faq", PageController, :faq)
  end

  scope "/", CentralWeb.Account, as: :account do
    pipe_through([:browser, :nomenu_layout])

    get("/login", SessionController, :new)
    post("/login", SessionController, :login)
    get("/logout", SessionController, :logout)
    post("/logout", SessionController, :logout)

    get("/forgot_password", SessionController, :forgot_password)
    post("/send_password_reset", SessionController, :send_password_reset)
    get("/password_reset/:value", SessionController, :password_reset_form)
    post("/password_reset/:value", SessionController, :password_reset_post)
    get("/one_time_login/:value", SessionController, :one_time_login)

    get("/initial_setup/:key", SetupController, :setup)
  end

  scope "/account", CentralWeb.Account, as: :account do
    pipe_through([:browser, :protected, :standard_layout])

    get("/", GeneralController, :index)

    get("/edit/details", RegistrationController, :edit_details)
    put("/edit/details", RegistrationController, :update_details)
    get("/edit/password", RegistrationController, :edit_password)
    put("/edit/password", RegistrationController, :update_password)

    delete("/groups/delete_membership/:group_id/:user_id", GroupController, :delete_membership)
    put("/groups/update_membership/:group_id/:user_id", GroupController, :update_membership)

    post("/groups/create_membership", GroupController, :create_membership)
    post("/groups/create_invite", GroupController, :create_invite)
    delete("/groups/delete_invite/:group_id/:user_id", GroupController, :delete_invite)
    put("/groups/respond_to_invite/:group_id/:response", GroupController, :respond_to_invite)
    put("/groups/promote/:group_id/:user_id", GroupController, :promote)
    put("/groups/demote/:group_id/:user_id", GroupController, :demote)

    resources("/groups", GroupController, only: [:index, :show, :edit, :update])
  end

  scope "/config", CentralWeb.Config do
    pipe_through([:browser, :protected, :standard_layout])

    resources("/user", UserConfigController, only: [:index, :edit, :update, :new, :create, :delete])
  end

  scope "/account", CentralWeb.Account, as: :account do
    pipe_through([:browser, :standard_layout])

    get("/registrations/new/:code", RegistrationController, :new)
    get("/registrations/new", RegistrationController, :new)
    post("/registrations/create", RegistrationController, :create)
  end

  scope "/quick", CentralWeb.General.QuickAction, as: :quick_action do
    pipe_through([:protected_api])

    get("/ajax", AjaxController, :index)
  end

  scope "/logging", CentralWeb.Logging, as: :logging do
    pipe_through([:browser, :protected, :standard_layout])

    get("/", GeneralController, :index)

    get("/audit/search", AuditLogController, :index)
    post("/audit/search", AuditLogController, :search)
    resources("/audit", AuditLogController, only: [:index, :show])

    get("/page_views/report", PageViewLogController, :report)
    post("/page_views/report", PageViewLogController, :report)
    get("/page_views/search", PageViewLogController, :index)
    post("/page_views/search", PageViewLogController, :search)
    get("/page_views/latest_users", PageViewLogController, :latest_users)
    resources("/page_views", PageViewLogController, only: [:index, :show, :delete])

    # Aggregate
    get("/aggregate_views", AggregateViewLogController, :index)
    get("/aggregate_views/show/:date", AggregateViewLogController, :show)
    get("/aggregate_views/perform", AggregateViewLogController, :perform_form)
    post("/aggregate_views/perform", AggregateViewLogController, :perform_post)

    # Errors
    get("/error_logs/delete_all", ErrorLogController, :delete_all_form)
    post("/error_logs/delete_all", ErrorLogController, :delete_all_post)
    resources("/error_logs", ErrorLogController, only: [:index, :show, :delete])

    # Reporting
    get("/reports", ReportController, :index)
    get("/reports/show/:name", ReportController, :show)
    post("/reports/show/:name", ReportController, :show)
  end

  scope "/communication", CentralWeb.Communication, as: :communication do
    pipe_through([:browser, :protected, :standard_layout])

    get("/notifications/handle_test/", NotificationController, :handle_test)
    post("/notifications/quick_new", NotificationController, :quick_new)
    get("/notifications/admin", NotificationController, :admin)

    get("/notifications/delete_all", NotificationController, :delete_all)
    get("/notifications/mark_all", NotificationController, :mark_all)
    resources("/notifications", NotificationController, only: [:index, :delete])
  end

  scope "/blog", CentralWeb.Communication do
    pipe_through([:browser, :nomenu_layout])

    get("/category/:category", BlogController, :category)
    get("/tag/:tag", BlogController, :tag)
    post("/comment/:id", BlogController, :add_comment)
    get("/file/:url_name", BlogController, :show_file)

    get("/", BlogController, :index)
    get("/:id", BlogController, :show)
  end

  scope "/blog_admin", CentralWeb.Communication, as: :blog do
    pipe_through([:browser, :protected, :standard_layout])

    resources("/posts", PostController)
    resources("/comments", CommentController)

    resources("/categories", CategoryController,
      only: [:index, :new, :create, :edit, :update, :delete]
    )
  end

  # Extra block to stop it being blog_blog_files_path
  scope "/blog_admin", CentralWeb.Communication do
    pipe_through([:browser, :protected, :standard_layout])

    # get "/blog_files/search", BlogFileController, :index
    # post "/blog_files/search", BlogFileController, :search
    resources("/files", BlogFileController)
  end

  scope "/admin", CentralWeb.Admin, as: :admin do
    pipe_through([:browser, :protected, :standard_layout])

    get("/", GeneralController, :index)

    post("/users/config/create", UserController, :config_create)
    get("/users/config/delete/:user_id/:key", UserController, :config_delete)

    # Users
    get("/users/latest", GeneralController, :latest_users)
    get("/users/permissions/:id", UserController, :edit_permissions)
    post("/users/permissions/:id", UserController, :update_permissions)
    post("/users/copy_permissions/:id", UserController, :copy_permissions)
    get("/users/delete_check/:id", UserController, :delete_check)

    resources("/users", UserController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )

    get("/users/reset_password/:id", UserController, :reset_password)
    get("/users/search", UserController, :index)
    post("/users/search", UserController, :search)

    # Groups
    post("/groups/create_membership", GroupController, :create_membership)
    get("/groups/delete_membership/:group_id/:user_id", GroupController, :delete_membership)
    get("/groups/update_membership/:group_id/:user_id", GroupController, :update_membership)
    # get "/groups/search", GroupController, :index
    post("/groups/search", GroupController, :search)

    get("/groups/delete_check/:id", GroupController, :delete_check)
    resources("/groups", GroupController)

    # Codes
    resources("/codes", CodeController)
    put("/codes/extend/:id/:hours", CodeController, :extend)


    # Config
    resources("/site", SiteConfigController, only: [:index, :edit, :update, :delete])

    # Tools
    get("/tools", ToolController, :index)
    get("/tools/falist", ToolController, :falist)
    get("/tools/test_error", ToolController, :test_error)
    get("/tools/test_page", ToolController, :test_page)
    get("/tools/coverage", ToolController, :coverage_form)
    post("/tools/coverage", ToolController, :coverage_post)
    get("/tools/oban", ToolController, :oban_dashboard)
    get("/tools/oban/action", ToolController, :oban_action)
    get("/tools/conn_params", ToolController, :conn_params)
  end

  # Live dashboard
  import Phoenix.LiveDashboard.Router

  scope "/logging/live", CentralWeb, as: :logging_live do
    pipe_through([:browser, :protected, :standard_layout, :logging_live_auth])

    live_dashboard("/dashboard",
      metrics: CentralWeb.Telemetry,
      ecto_repos: [Central.Repo],
      additional_pages: [
        # live_dashboard_additional_pages
      ]
    )
  end

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
    put("/leave_clan/:clan_id", ClanController, :leave_clan)
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

    get("/ratings/leaderboard", RatingsController, :leaderboard)
    get("/ratings/leaderboard/:type", RatingsController, :leaderboard)

    get("/matches/ratings", MatchController, :ratings)
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

  scope "/teiserver/account", TeiserverWeb.Account.PartyLive, as: :ts_game do
    pipe_through([:browser, :standard_layout, :protected])

    live("/parties", Index, :index)
    live("/parties/:mode", Index, :index)
    live("/parties/show/:id", Show, :show)
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
    get("/infolog/search", InfologController, :index)
    post("/infolog/search", InfologController, :search)
    resources("/infolog", InfologController, only: [:index, :show, :delete])

    get("/exports/download/:id", ExportsController, :download)
    resources("/exports", ExportsController, only: [:index])

    get("/show/:name", ReportController, :show)
    post("/show/:name", ReportController, :show)

    # Ratings
    get("/ratings/balance_tester", RatingController, :balance_tester)
    post("/ratings/balance_tester", RatingController, :balance_tester)

    get("/ratings/distribution_table", RatingController, :distribution_table)
    post("/ratings/distribution_table", RatingController, :distribution_table)
    get("/ratings/distribution_graph", RatingController, :distribution_graph)
    post("/ratings/distribution_graph", RatingController, :distribution_graph)
  end

  # API
  scope "/teiserver/api", TeiserverWeb.API do
    pipe_through :api
    post "/login", SessionController, :login
  end

  scope "/teiserver/api/beans", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    post("/up", BeansController, :up)
    post("/update_site_config", BeansController, :update_site_config)
    post("/create_user", BeansController, :create_user)
    post("/db_update_user", BeansController, :db_update_user)
    post("/ts_update_user", BeansController, :ts_update_user)
  end

  scope "/teiserver/api/spads", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    get "/get_rating/:target_id/:type", SpadsController, :get_rating
    get "/get_rating/:caller_id/:target_id/:type", SpadsController, :get_rating

    get "/balance_battle", SpadsController, :balance_battle
    post "/balance_battle", SpadsController, :balance_battle
  end

  scope "/teiserver/api/public", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    get "/leaderboard/:type", PublicController, :leaderboard
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

  scope "/teiserver/admin", TeiserverWeb.PartyLive, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    live("/party", Index, :index)
    live("/party/:id", Show, :show)
  end

  scope "/teiserver/admin", TeiserverWeb.AgentLive, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    live("/agent", Index, :index)
    # live("/agent/:id", Show, :show)
  end

  scope "/moderation", TeiserverWeb.Moderation, as: :moderation do
    pipe_through([:browser, :standard_layout, :protected])

    get("/", GeneralController, :index)

    get("/report/user/:id", ReportController, :user)
    resources("/report", ReportController, only: [:index, :show, :delete])

    get("/action/search", ActionController, :search)
    post("/action/search", ActionController, :search)
    get("/action/new_with_user", ActionController, :new_with_user)
    put("/action/halt/:id", ActionController, :halt)
    resources("/action", ActionController, only: [:index, :show, :new, :create, :edit, :update])

    get("/proposal/new_with_user", ProposalController, :new_with_user)
    put("/proposal/vote/:proposal_id/:direction", ProposalController, :vote)
    resources("/proposal", ProposalController, only: [:index, :show, :new, :create, :edit, :update])

    put("/ban/:id/disable", BanController, :disable)
    put("/ban/:id/enable", BanController, :enable)
    get("/ban/new_with_user", BanController, :new_with_user)
    resources("/ban", BanController, only: [:index, :show, :new, :create])

    get("/report_form/success", ReportFormController, :success)
    post("/report_form", ReportFormController, :create)
    get("/report_form/:id", ReportFormController, :index)
  end

  scope "/admin", TeiserverWeb.Admin, as: :admin do
    pipe_through([:browser, :standard_layout, :protected])
    resources("/lobby_policies", LobbyPolicyController, only: [:index, :new, :create, :show, :edit, :update, :delete])
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
    get("/users/smurf_search/:id", UserController, :smurf_search)
    get("/users/smurf_merge_form/:from_id/:to_id", UserController, :smurf_merge_form)
    post("/users/smurf_merge_post/:from_id/:to_id", UserController, :smurf_merge_post)
    delete("/users/delete_smurf_key/:id", UserController, :delete_smurf_key)
    get("/users/full_chat/:id", UserController, :full_chat)
    get("/users/full_chat/:id/:page", UserController, :full_chat)
    get("/users/search", UserController, :index)
    post("/users/set_stat", UserController, :set_stat)
    get("/users/data_search", UserController, :data_search)
    post("/users/data_search", UserController, :data_search)
    post("/users/search", UserController, :search)
    get("/users/applying/:id", UserController, :applying)
    get("/users/ratings_form/:id", UserController, :ratings_form)
    post("/users/ratings_post/:id", UserController, :ratings_post)
    get("/users/ratings/:id", UserController, :ratings)
    resources("/user", UserController)

    resources("/badge_types", BadgeTypeController)
    resources("/accolades", AccoladeController, only: [:index, :show, :delete])
    get("/accolades/user/:user_id", AccoladeController, :user_show)

    get("/matches/by_server/:uuid", MatchController, :server_index)
    get("/matches/search", MatchController, :index)
    post("/matches/search", MatchController, :search)
    get("/matches/user/:user_id", MatchController, :user_show)
    get("/matches/chat/:id", MatchController, :chat)
    resources("/matches", MatchController, only: [:index, :show, :delete])

    resources("/chat", ChatController, only: [:index])
    post("/chat", ChatController, :index)

    resources("/achievements", AchievementController)

    get("/lobbies/:id/server_chat/download", LobbyController, :server_chat_download)
    get("/lobbies/:id/server_chat", LobbyController, :server_chat)
    get("/lobbies/:id/server_chat/:page", LobbyController, :server_chat)
    get("/lobbies/:id/lobby_chat/download", LobbyController, :lobby_chat_download)
    get("/lobbies/:id/lobby_chat", LobbyController, :lobby_chat)
    get("/lobbies/:id/lobby_chat/:page", LobbyController, :lobby_chat)
  end
end
