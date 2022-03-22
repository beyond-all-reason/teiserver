defmodule CentralWeb.ErrorView do
  use CentralWeb, :view

  import Central.Logging.Helpers, only: [add_error_log: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-exclamation-triangle"

  @spec view_colour() :: atom
  def view_colour(), do: :danger2

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def render("403.html", assigns) do
    render("403_forbidden.html", assigns)
  end

  def render("404.html", assigns) do
    render("404_not_found.html", assigns)
  end

  def render("500.html", %{reason: _} = error) do
    case error.reason do
      #       %Decimal.Error{message: "Error converting decimal value of " <> v} ->
      #         render "500_graceful.html", Map.merge(error, %{
      #           msg: "The system tried converting some text into a number: #{v}. Unfortunately the system isn't sure how to convert this. If you can spot the issue then hit the back button and try again.",
      #           info: """
      # error: #{error.reason |> Kernel.inspect}
      # value: #{v}
      # """
      #         })

      %Timex.Parse.ParseError{message: "Expected" <> _v} ->
        render(
          "500_graceful.html",
          Map.merge(error, %{
            msg:
              "There was an issue trying to read in a date, please hit the back button and review the data being submitted.",
            info: ""
          })
        )

      _ ->
        db_username =
          Application.get_env(:central, Central.Repo)
          |> Keyword.get(:username)

        # If in test mode we don't want to actually log errors since
        # there is an issue with converting the params into a map
        error_log =
          if db_username =~ "_test" do
            %{}
          else
            add_error_log(error)
          end

        render("500_internal.html", Map.merge(error, %{error_log: error_log, error: error}))
    end
  end

  def render("500.html", error) do
    render("500.html", %{reason: error})
  end
end
