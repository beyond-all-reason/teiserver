defmodule CentralWeb.General.PageController do
  use CentralWeb, :controller

  def index(conn, _params) do
    maybe_user = Guardian.Plug.current_resource(conn)
    if maybe_user do
      render(conn, "auth_index.html")
    else
      conn
      |> redirect(to: Routes.account_session_path(conn, :new))
    end
  end

  def recache(conn, _params) do
    Central.Account.recache_user(conn.current_user)
    {_, redirect} = List.keyfind(conn.req_headers, "referer", 0)

    conn
    |> redirect(external: redirect)
  end

  def faq(conn, _params) do
    conn
    |> render("faq.html")
  end

  def browser_info(conn, _params) do
    conn
    |> render("browser_info.html")
  end

  def human_time(conn, %{"human_time_entry" => entry}) do
    entry = String.trim(entry)

    case HumanTime.repeating(entry) do
      {:error, msg} ->
        if Enum.member?([""], entry) do
          conn
          |> assign(:error, nil)
          |> assign(:results, nil)
          |> assign(:entry, nil)
          |> render("human_time.html")
        else
          conn
          |> assign(:error, msg)
          |> assign(:results, nil)
          |> assign(:entry, entry)
          |> render("human_time.html")
        end

      {:ok, results} ->
        results = results
        |> Enum.take(5)

        conn
        |> assign(:error, nil)
        |> assign(:results, results)
        |> assign(:entry, entry)
        |> render("human_time.html")
    end
  end

  def human_time(conn, _params) do
    conn
    |> assign(:entry, nil)
    |> assign(:error, nil)
    |> assign(:results, nil)
    |> render("human_time.html")
  end

  # def load_test(conn, _params) do
  #   env_flag = Application.get_env(:central, Central.General.LoadTestServer)
  #   |> Keyword.get(:enable_loadtest)

  #   if env_flag do
  #     {_, user_agent} = List.keyfind(conn.req_headers, "user-agent", 0) || {nil, "Not found"}

  #     uid = 100_000_000_000_000..999_999_999_999_999
  #     |> Enum.random()
  #     |> to_string

  #     conn
  #     |> assign(:uid, uid)
  #     |> assign(:start_time, Timex.now())
  #     |> assign(:user_agent, user_agent)
  #     |> render("load_test.html")
  #   else
  #     conn
  #     |> redirect(to: "/")
  #   end
  # end

  # def some_text(conn, _params) do
  #   conn
  #   |> put_layout("blank.html")
  #   |> render("some_text.html")
  # end
end
