defmodule Mix.Tasks.Teiserver.DevSetup do
  @moduledoc """
  Sets up everything needed for local development:
  - Root user
  - OAuth applications
  - Test users
  """
  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started([:ecto, :ecto_sql, :tzdata])
    Teiserver.Repo.start_link()

    # Create root user
    create_root_user()

    # Setup OAuth applications
    setup_oauth_apps()

    # Configure OAuth redirect URIs
    configure_redirect_uris()

    # Create test users
    create_test_users()

    Mix.shell().info("✅ Dev setup complete!")
  end

  defp create_root_user do
    # Use Repo.get_by to get a proper Ecto struct
    user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")

    case user do
      nil ->
        Mix.shell().info("📝 Creating root user...")

        try do
          {:ok, created_user} =
            Teiserver.Account.script_create_user(%{
              name: "root",
              email: "root@localhost",
              password: "root123",
              roles: ["Admin", "Verified"],
              verified: true
            })

          # Ensure verified flag and roles are set BOTH in struct and data (must match!)
          changeset = Ecto.Changeset.change(created_user,
            roles: ["Admin", "Verified"],
            data: Map.merge(created_user.data, %{"verified" => true, "roles" => ["Admin", "Verified"]})
          )
          Teiserver.Repo.update!(changeset)

          # Clear cache if it's initialized (might not be during initial setup)
          try do
            Teiserver.Account.recache_user(created_user.id)
          rescue
            _ -> :ok  # Cache not initialized yet, that's fine
          end

          Mix.shell().info("✅ Root user created: root@localhost / root123")
        rescue
          ArgumentError ->
            # PubSub not running yet - that's ok, we're in a mix task
            Mix.shell().info("✅ Root user created: root@localhost / root123")
        end

      existing_user ->
        # Ensure existing root user is verified and password is correct
        try do
          # Update verified flag and roles BOTH in struct and data (must match!)
          changeset = Ecto.Changeset.change(existing_user,
            roles: ["Admin", "Verified"],
            data: Map.merge(existing_user.data, %{"verified" => true, "roles" => ["Admin", "Verified"]})
          )
          Teiserver.Repo.update!(changeset)

          # Reload user to get updated data
          updated_user = Teiserver.Repo.get!(Teiserver.Account.User, existing_user.id)

          # Update password using password_reset (doesn't require existing password)
          Teiserver.Account.password_reset_update_user(updated_user, %{"password" => "root123"})

          # Clear cache to pick up changes
          Teiserver.Account.recache_user(existing_user.id)

          Mix.shell().info("✅ Root user verified and updated: root@localhost / root123")
        rescue
          ArgumentError ->
            Mix.shell().info("✅ Root user verified and ready: root@localhost / root123")
        end
    end
  end

  defp setup_oauth_apps do
    Mix.shell().info("📝 Setting up OAuth applications...")
    Teiserver.Tachyon.Tasks.SetupApps.ensure_lobby_app()
    Teiserver.Tachyon.Tasks.SetupApps.ensure_asset_admin_app()
    Teiserver.Tachyon.Tasks.SetupApps.ensure_user_admin_app()
  end

  defp configure_redirect_uris do
    app = Teiserver.OAuth.ApplicationQueries.get_application_by_uid("generic_lobby")

    expected_uris = [
      "http://127.0.0.1/oauth2callback",
      "http://localhost/oauth2callback"
    ]

    if app && Enum.sort(app.redirect_uris) != Enum.sort(expected_uris) do
      Mix.shell().info("📝 Configuring OAuth redirect URIs...")

      Teiserver.OAuth.update_application(app, %{
        "redirect_uris" => expected_uris
      })

      Mix.shell().info("✅ OAuth redirect URIs configured")
    else
      Mix.shell().info("✅ OAuth redirect URIs already configured")
    end
  end

  defp create_test_users do
    create_test_user("test@localhost", "TestUser", "pass")
    create_test_user("test2@localhost", "TestUser2", "pass")
  end

  defp create_test_user(email, name, password) do
    # Use Repo.get_by to get a proper Ecto struct
    user = Teiserver.Repo.get_by(Teiserver.Account.User, email: email)

    case user do
      nil ->
        Mix.shell().info("📝 Creating test user: #{email} / #{password}")

        try do
          {:ok, created_user} =
            Teiserver.Account.script_create_user(%{
              name: name,
              email: email,
              password: password,
              roles: ["Verified"],
              verified: true
            })

          # Ensure verified flag and roles are set BOTH in struct and data (must match!)
          changeset = Ecto.Changeset.change(created_user,
            roles: ["Verified"],
            data: Map.merge(created_user.data, %{"verified" => true, "roles" => ["Verified"]})
          )
          Teiserver.Repo.update!(changeset)

          # Clear cache if it's initialized (might not be during initial setup)
          try do
            Teiserver.Account.recache_user(created_user.id)
          rescue
            _ -> :ok  # Cache not initialized yet, that's fine
          end

          Mix.shell().info("✅ Test user created: #{email} / #{password}")
        rescue
          ArgumentError ->
            # PubSub not running yet - that's ok, we're in a mix task
            Mix.shell().info("✅ Test user created: #{email} / #{password}")
        end

      user ->
        # Update password and ensure verified flag
        try do
          # Update verified flag and roles BOTH in struct and data (must match!)
          changeset = Ecto.Changeset.change(user,
            roles: ["Verified"],
            data: Map.merge(user.data, %{"verified" => true, "roles" => ["Verified"]})
          )
          Teiserver.Repo.update!(changeset)

          # Reload user to get updated data
          updated_user = Teiserver.Repo.get!(Teiserver.Account.User, user.id)

          # Update password using password_reset (doesn't require existing password)
          Teiserver.Account.password_reset_update_user(updated_user, %{"password" => password})

          # Clear cache to pick up changes
          Teiserver.Account.recache_user(user.id)

          Mix.shell().info("✅ Test user verified and updated: #{email} / #{password}")
        rescue
          ArgumentError ->
            # PubSub not running yet - that's ok
            Mix.shell().info("✅ Test user ready: #{email} / #{password}")
        end
    end
  end
end
