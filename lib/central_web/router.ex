defmodule CentralWeb.Router do
  use CentralWeb, :router

  pipeline :dev_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Central.Dev,
      action: :dev_auth,
      user: {Central.Account.AuthLib, :current_user}
  end

  pipeline :admin_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Central.Admin.AdminLib,
      action: :admin_auth,
      user: {Central.Account.AuthLib, :current_user}
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Central.Logging.LoggingPlug)
    plug(Central.Account.AuthPipeline)
    plug(Central.Account.AuthPlug)
    plug(Central.General.CachePlug)
    plug(Central.Admin.AdminPlug)
    plug(Central.Communication.NotificationPlug)
  end

  pipeline :admin_layout do
    plug(:put_layout, {CentralWeb.LayoutView, "admin.html"})
  end

  pipeline :blank_layout do
    plug(:put_layout, {CentralWeb.LayoutView, "blank.html"})
  end

  pipeline :empty_layout do
    plug(:put_layout, {CentralWeb.LayoutView, "empty.html"})
  end

  pipeline :protected do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :protected_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Central.Logging.LoggingPlug)
    plug(Central.Account.AuthPipeline)
    plug(Central.Account.AuthPlug)
    plug(Central.General.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
    plug(Central.Admin.AdminPlug)
  end

  scope "/", CentralWeb.General, as: :general do
    pipe_through([:browser, :blank_layout])

    get("/recache", PageController, :recache)
    get("/browser_info", PageController, :browser_info)
    get("/", PageController, :index)
    get("/faq", PageController, :faq)
    get("/human_time", PageController, :human_time)
    post("/human_time", PageController, :human_time)
    get("/some_text", PageController, :some_text)

    get("/pixi", PixiController, :index)

    env_flag =
      Application.get_env(:central, Central.General.LoadTestServer)
      |> Keyword.get(:enable_loadtest)

    if env_flag do
      get("/load_test", PageController, :load_test)
    end
  end

  scope "/", CentralWeb.Account, as: :account do
    pipe_through([:browser, :blank_layout])

    get("/login", SessionController, :new)
    post("/login", SessionController, :login)
    get("/logout", SessionController, :logout)
    post("/logout", SessionController, :logout)

    get("/forgot_password", SessionController, :forgot_password)
    post("/send_password_reset", SessionController, :send_password_reset)
    get("/password_reset/:value", SessionController, :password_reset_form)
    post("/password_reset/:value", SessionController, :password_reset_post)

    get("/initial_setup/:key", SetupController, :setup)
  end

  scope "/account", CentralWeb.Account, as: :account do
    pipe_through([:browser, :protected, :admin_layout])

    get("/", GeneralController, :index)

    get("/edit/details", RegistrationController, :edit_details)
    put("/edit/details", RegistrationController, :update_details)
    get("/edit/password", RegistrationController, :edit_password)
    put("/edit/password", RegistrationController, :update_password)

    post("/groups/create_membership", GroupController, :create_membership)
    delete("/groups/delete_membership/:group_id/:user_id", GroupController, :delete_membership)
    put("/groups/update_membership/:group_id/:user_id", GroupController, :update_membership)

    resources("/groups", GroupController, only: [:index, :show, :edit, :update])

    get("/groups/:group_id/settings", GroupController, :show_settings)
    post("/groups/:group_id/settings/:key", GroupController, :update_settings)

    get("/report/new/:target_id", ReportController, :new)
    post("/report/create", ReportController, :create)
  end

  scope "/config", CentralWeb.Config do
    pipe_through([:browser, :protected, :admin_layout])

    resources("/user", UserConfigController, only: [:index, :edit, :update, :new, :create])
  end

  scope "/account", CentralWeb.Account, as: :account do
    pipe_through([:browser, :admin_layout])

    get("/registrations/new", RegistrationController, :new)
    post("/registrations/create", RegistrationController, :create)
  end

  scope "/quick", CentralWeb.General.QuickAction, as: :quick_action do
    pipe_through([:protected_api])

    get("/ajax", AjaxController, :index)
  end

  scope "/logging", CentralWeb.Logging, as: :logging do
    pipe_through([:browser, :protected, :admin_layout])

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
    pipe_through([:browser, :protected, :admin_layout])

    get("/notifications/handle_test/", NotificationController, :handle_test)
    post("/notifications/quick_new", NotificationController, :quick_new)
    get("/notifications/admin", NotificationController, :admin)

    get("/notifications/delete_all", NotificationController, :delete_all)
    get("/notifications/mark_all", NotificationController, :mark_all)
    resources("/notifications", NotificationController, only: [:index, :delete])
  end

  scope "/blog", CentralWeb.Communication do
    pipe_through([:browser, :blank_layout])

    get("/category/:category", BlogController, :category)
    get("/tag/:tag", BlogController, :tag)
    post("/comment/:id", BlogController, :add_comment)
    get("/file/:url_name", BlogController, :show_file)

    get("/", BlogController, :index)
    get("/:id", BlogController, :show)
  end

  scope "/blog_admin", CentralWeb.Communication, as: :blog do
    pipe_through([:browser, :protected, :admin_layout])

    resources("/posts", PostController)
    resources("/comments", CommentController)

    resources("/categories", CategoryController,
      only: [:index, :new, :create, :edit, :update, :delete]
    )
  end

  # Extra block to stop it being blog_blog_files_path
  scope "/blog_admin", CentralWeb.Communication do
    pipe_through([:browser, :protected, :admin_layout])

    # get "/blog_files/search", BlogFileController, :index
    # post "/blog_files/search", BlogFileController, :search
    resources("/files", BlogFileController)
  end

  scope "/admin", CentralWeb.Admin, as: :admin do
    pipe_through([:browser, :protected, :admin_layout])

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

    # User reports
    resources("/reports", ReportController, only: [:index, :show])
    get("/reports/user/:id", ReportController, :user_show)
    get("/reports/:id/respond", ReportController, :respond_form)
    put("/reports/:id/respond", ReportController, :respond_post)

    # Groups
    post("/groups/create_membership", GroupController, :create_membership)
    get("/groups/delete_membership/:group_id/:user_id", GroupController, :delete_membership)
    get("/groups/update_membership/:group_id/:user_id", GroupController, :update_membership)
    # get "/groups/search", GroupController, :index
    post("/groups/search", GroupController, :search)

    get("/groups/delete_check/:id", GroupController, :delete_check)
    resources("/groups", GroupController)

    get("/groups/:group_id/settings", GroupController, :show_settings)
    post("/groups/:group_id/settings/:key", GroupController, :update_settings)

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

  scope "/admin", CentralWeb.Admin, as: :admin do
    pipe_through([:browser, :protected, :admin_layout, :admin_auth])

    live_dashboard("/dashboard", metrics: CentralWeb.Telemetry)
  end

  use TeiserverWeb.Router
  teiserver_routes()
end
