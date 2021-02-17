defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/teiserver", TeiserverWeb.Admin, as: :teiserver do
        get "/", GeneralController, :index
      end
    end

  end
end
