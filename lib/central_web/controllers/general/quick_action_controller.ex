defmodule CentralWeb.General.QuickAction.AjaxController do
  use CentralWeb, :controller

  def index(conn, _params) do
    data =
      Central.General.QuickAction.get_items()
      |> Enum.filter(fn r ->
        if Map.get(r, :permissions, nil) do
          allow?(conn, r.permissions)
        else
          true
        end
      end)
      |> Enum.map(fn row ->
        kw = Map.get(row, :keywords, [])

        extra_kw =
          row.label
          |> String.downcase()
          |> String.split(" ")

        Map.put(row, :keywords, kw ++ extra_kw ++ [row.label |> String.downcase()])
      end)
      |> Enum.sort_by(fn row -> row.label end)

    search_item = %{
      icon: "fas fa-search",
      keywords: "search",
      label: "Site search",
      permissions: [],
      input: "s",
      method: "get",
      url: "/search"
    }

    conn
    |> put_status(:ok)
    |> put_resp_content_type("application/json")
    |> assign(:data, [search_item] ++ data)
    |> do_not_log
    |> render("response.json")
  end
end
