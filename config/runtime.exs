import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/teiserver start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :teiserver, TeiserverWeb.Endpoint, server: true
end

# Only do some runtime configuration in production since in dev and tests the
# files are automatically recompiled on the fly and thus, config/{dev,test}.exs
# are just fine
if config_env() == :prod do

  # this is used in lib/teiserver_web/controllers/account/setup_controller.ex
  # as a special endpoint to create the root user. Setting it to empty or nil
  # will disable the functionality completely.
  # There is already a root user, so disable it
  config :teiserver, Teiserver.Setup, key: nil

end
