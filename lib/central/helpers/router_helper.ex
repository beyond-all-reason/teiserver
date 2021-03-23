# Trying to get this to work so the extra routers
# can be configured, sadly unable to find a way so far
defmodule Central.RouterHelper do
  defmacro use_routers() do
    routers = Application.get_env(:central, Extensions)[:routers]

    IO.puts ""
    IO.inspect routers
    IO.puts ""

    for mod <- routers do
      quote do
        IO.puts ""
        IO.inspect unquote(mod)
        IO.puts ""
        unquote(mod)
      end
    end

    # quote do
    #   m = unquote(r)
    #   use unquote(r)
    #   m.routes()
    # end
  end
end
