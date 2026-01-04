defmodule TeiserverWeb.PaginationComponents do
  @moduledoc """
  Pagination components and utilities.
  """
  use Phoenix.Component

  @doc """
  Renders a pagination component with page numbers, navigation, and search parameter preservation.

  ## Examples
      
      # Basic pagination
      <.pagination
        page={@page}
        total_pages={@total_pages}
        base_url="/admin/users"
        class="mt-3"
      />
      
      # Full pagination with search parameter preservation (Controller)
      <.pagination
        page={@page}
        total_pages={@total_pages}
        base_url="/admin/users"
        limit={@limit}
        total_count={@total_count}
        current_count={@current_count}
        include_params={["search", "limit", "name", "order"]}
        current_params={@conn.params}
        show_go_to={@total_pages > 5}
        class="mt-3"
      />
      
      # Full pagination with search parameter preservation (LiveView)
      <.pagination
        page={@page}
        total_pages={@total_pages}
        base_url="/moderation/overwatch"
        limit={@limit}
        total_count={@total_count}
        current_count={@current_count}
        include_params={["actioned-filter", "closed-filter", "kind-filter", "timeframe-filter", "target_id", "limit"]}
        current_params={@filters}
        show_go_to={@total_pages > 5}
        class="mt-3"
      />
      
  ## Options
      
  * `:page` - Current page number (0-based)
  * `:total_pages` - Total number of pages (required for page number display)
  * `:base_url` - Base URL for pagination links
  * `:class` - Additional CSS classes
  * `:limit` - Number of items per page (for display and limit dropdown)
  * `:total_count` - Total number of items (for display purposes)
  * `:current_count` - Number of items on current page
  * `:show_go_to` - Whether to show "go to page" input (default: true)
  * `:show_limit_dropdown` - Whether to show limit dropdown (default: true)
  * `:max_pages` - Maximum number of page links to show (default: 7)
  * `:include_params` - List of parameter names to preserve in pagination (e.g., ["search", "limit", "name"])
  * `:current_params` - Map of current parameters to preserve (typically @conn.params for controllers or @filters for LiveViews)

  ## Features

  * **Search Parameter Preservation**: Automatically preserves search filters, sort orders, and other parameters when navigating between pages
  * **Smart Pagination**: Shows ellipsis (...) for large page ranges to keep navigation clean
  * **Limit Dropdown**: Allows users to change items per page (10, 25, 50, 100, 500)
  * **Go to Page**: Direct page navigation input for large datasets
  * **Responsive Design**: Adapts to different screen sizes

  ## Usage Patterns

  ### Controllers
  Use `current_params={@conn.params}` to preserve URL parameters from the request:

      current_params={@conn.params}
      include_params={["search", "limit", "name", "order"]}

  ### LiveViews  
  Use `current_params={@filters}` to preserve LiveView filter state:

      current_params={@filters}
      include_params={["actioned-filter", "closed-filter", "kind-filter", "limit"]}

  ### Special Cases
  Some controllers merge additional parameters:

      current_params={Map.merge(@conn.params, %{"limit" => @limit})}
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :base_url, :string, required: true
  attr :class, :string, default: ""
  attr :limit, :integer, default: nil
  attr :total_count, :integer, default: nil
  attr :current_count, :integer, default: nil
  attr :show_go_to, :boolean, default: true
  attr :show_limit_dropdown, :boolean, default: true
  attr :max_pages, :integer, default: 7
  attr :include_params, :list, default: []
  attr :current_params, :map, default: %{}

  def pagination(assigns) do
    assigns =
      assign(
        assigns,
        :page_range,
        build_page_range(assigns.page, assigns.total_pages, assigns.max_pages)
      )

    ~H"""
    <div class={"row mt-3 #{@class}"}>
      <div class="col-md-6">
        <!-- Info Section -->
        <%= if @limit != nil and @total_count != nil and @current_count != nil do %>
          <div class="text-muted">
            Showing {@page * @limit + 1}-{@page * @limit + @current_count} of {@total_count}
          </div>
        <% end %>
      </div>

      <div class="col-md-6">
        <div class="d-flex justify-content-end align-items-center">
          <!-- Limit Dropdown -->
          <%= if @show_limit_dropdown and @limit != nil do %>
            <div class="me-3">
              <div class="input-group input-group-sm" style="width: 130px;">
                <span class="input-group-text">Show</span>
                <div class="dropdown">
                  <button
                    class="btn btn-outline-secondary dropdown-toggle"
                    type="button"
                    data-bs-toggle="dropdown"
                  >
                    {@limit}
                  </button>
                  <ul class="dropdown-menu">
                    <li>
                      <a
                        class="dropdown-item"
                        href={
                          build_pagination_url(@base_url, @current_params, @include_params, %{
                            "page" => "1",
                            "limit" => "10"
                          })
                        }
                      >
                        10
                      </a>
                    </li>
                    <li>
                      <a
                        class="dropdown-item"
                        href={
                          build_pagination_url(@base_url, @current_params, @include_params, %{
                            "page" => "1",
                            "limit" => "25"
                          })
                        }
                      >
                        25
                      </a>
                    </li>
                    <li>
                      <a
                        class="dropdown-item"
                        href={
                          build_pagination_url(@base_url, @current_params, @include_params, %{
                            "page" => "1",
                            "limit" => "50"
                          })
                        }
                      >
                        50
                      </a>
                    </li>
                    <li>
                      <a
                        class="dropdown-item"
                        href={
                          build_pagination_url(@base_url, @current_params, @include_params, %{
                            "page" => "1",
                            "limit" => "100"
                          })
                        }
                      >
                        100
                      </a>
                    </li>
                    <li>
                      <a
                        class="dropdown-item"
                        href={
                          build_pagination_url(@base_url, @current_params, @include_params, %{
                            "page" => "1",
                            "limit" => "500"
                          })
                        }
                      >
                        500
                      </a>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          <% end %>
          
    <!-- Go to Page Input -->
          <%= if @show_go_to and @total_pages > 5 do %>
            <div class="me-3">
              <div class="input-group input-group-sm" style="width: 160px;">
                <span class="input-group-text">Go to</span>
                <input
                  type="number"
                  class="form-control"
                  placeholder="Page"
                  min="1"
                  max={@total_pages}
                  id="go-to-page-input"
                />
                <button
                  class="btn btn-outline-secondary"
                  type="button"
                  onclick={"var url = '#{build_pagination_url(@base_url, @current_params, @include_params, %{"page" => "PAGE_PLACEHOLDER"}, []) |> String.replace("'", "\\'")}'; window.location.href = url.replace('PAGE_PLACEHOLDER', document.getElementById('go-to-page-input').value);"}
                >
                  <Fontawesome.icon icon="arrow-right" style="solid" />
                </button>
              </div>
            </div>
          <% end %>
          
    <!-- Pagination Navigation -->
          <%= if @total_pages > 1 do %>
            <nav aria-label="Page navigation">
              <ul class="pagination pagination-sm mb-0">
                <!-- Previous Button -->
                <li class={"page-item #{if @page == 0, do: "disabled"}"}>
                  <%= if @page > 0 do %>
                    <.link
                      navigate={
                        build_pagination_url(
                          @base_url,
                          @current_params,
                          @include_params,
                          %{"page" => @page + 1},
                          []
                        )
                      }
                      class="page-link"
                    >
                      <Fontawesome.icon icon="chevron-left" style="solid" />
                    </.link>
                  <% else %>
                    <span class="page-link">
                      <Fontawesome.icon icon="chevron-left" style="solid" />
                    </span>
                  <% end %>
                </li>
                
    <!-- Page Numbers -->
                <%= for page_num <- @page_range do %>
                  <%= if page_num == :ellipsis do %>
                    <li class="page-item disabled">
                      <span class="page-link">…</span>
                    </li>
                  <% else %>
                    <li class={"page-item #{if page_num == @page, do: "active"}"}>
                      <%= if page_num == @page do %>
                        <span class="page-link">
                          {page_num + 1}
                          <span class="visually-hidden">(current)</span>
                        </span>
                      <% else %>
                        <.link
                          navigate={
                            build_pagination_url(
                              @base_url,
                              @current_params,
                              @include_params,
                              %{"page" => page_num + 1},
                              []
                            )
                          }
                          class="page-link"
                        >
                          {page_num + 1}
                        </.link>
                      <% end %>
                    </li>
                  <% end %>
                <% end %>
                
    <!-- Next Button -->
                <li class={"page-item #{if @page >= @total_pages - 1, do: "disabled"}"}>
                  <%= if @page < @total_pages - 1 do %>
                    <.link
                      navigate={
                        build_pagination_url(
                          @base_url,
                          @current_params,
                          @include_params,
                          %{"page" => @page + 2},
                          []
                        )
                      }
                      class="page-link"
                    >
                      <Fontawesome.icon icon="chevron-right" style="solid" />
                    </.link>
                  <% else %>
                    <span class="page-link">
                      <Fontawesome.icon icon="chevron-right" style="solid" />
                    </span>
                  <% end %>
                </li>
              </ul>
            </nav>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Builds a pagination URL with specified parameters and optional overrides.
  This function is used internally by the pagination component and can also be used
  directly for custom pagination logic.

  ## Options

  * `base_url` - Base URL or connection (string or Plug.Conn)
  * `params` - All available parameters (typically @conn.params or similar)
  * `include_params` - List of parameter names to include in the URL
  * `overrides` - Map of parameters to override (e.g., %{"page" => 5})
  * `exclusions` - List of parameter names to exclude (e.g., ["page", "limit"])

  ## Examples

      # Build URL with page override
      build_pagination_url("/admin/users", params, ["limit", "kind"], %{"page" => 5})

      # Build URL with page override and exclude limit
      build_pagination_url("/admin/users", params, ["limit", "kind"], %{"page" => 1}, ["limit"])

      # Build URL with no overrides or exclusions
      build_pagination_url("/admin/users", params, ["limit", "kind"])
      
      # Build URL for LiveView push_patch (preserving all search parameters)
      build_pagination_url("/moderation/overwatch", filters, 
        ["actioned-filter", "closed-filter", "kind-filter", "timeframe-filter", "target_id", "limit"], 
        %{"page" => "1"})

  ## Behavior

  * **Parameter Preservation**: Only includes parameters specified in `include_params`
  * **Overrides**: Parameters in `overrides` take precedence over existing params
  * **Exclusions**: Parameters in `exclusions` are removed from the final URL
  * **Empty Values**: Automatically filters out empty strings and nil values
  * **URL Encoding**: Properly encodes parameter values for safe URLs
  """
  def build_pagination_url(base_url, params, include_params, overrides \\ %{}, exclusions \\ []) do
    # Use centralized parameter preparation with exclusions
    search_params = prepare_params(params, include_params, overrides, exclusions)

    if Enum.empty?(search_params) do
      get_base_path(base_url)
    else
      query_string = build_query_string(search_params)
      "#{get_base_path(base_url)}?#{query_string}"
    end
  end

  # Helper function for building query strings consistently
  defp build_query_string(params) do
    params
    # credo:disable-for-lines:2 Credo.Check.Refactor.MapJoin
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end

  # Centralized parameter preparation with overrides and exclusions
  defp prepare_params(params, include_params, overrides, exclusions) do
    params
    |> Map.take(include_params)
    |> Map.merge(overrides)
    |> Map.drop(exclusions)
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
  end

  # Extract base path from URL or connection
  defp get_base_path(base_url) when is_binary(base_url), do: base_url
  defp get_base_path(conn) when is_map(conn), do: conn.request_path

  # Helper function to build the page range for pagination
  # Returns a list like [0, 1, :ellipsis, 5, 6, 7] for smart pagination
  defp build_page_range(_, 0, _), do: [0]

  defp build_page_range(_current_page, total_pages, max_pages) when total_pages <= max_pages do
    # If total pages is small, show all pages
    Enum.to_list(0..(total_pages - 1))
  end

  defp build_page_range(current_page, total_pages, max_pages) do
    # Smart pagination with ellipsis
    # Reserve space for first, last, and ellipsis
    half = div(max_pages - 3, 2)

    cond do
      # Near the beginning: [0, 1, 2, 3, ..., last]
      current_page < half + 2 ->
        Enum.to_list(0..(max_pages - 3)) ++ [:ellipsis, total_pages - 1]

      # Near the end: [0, ..., n-3, n-2, n-1]
      current_page > total_pages - half - 3 ->
        [0, :ellipsis] ++ Enum.to_list((total_pages - max_pages + 2)..(total_pages - 1))

      # In the middle: [0, ..., current-1, current, current+1, ..., last]
      true ->
        [0, :ellipsis] ++
          Enum.to_list((current_page - half)..(current_page + half)) ++
          [:ellipsis, total_pages - 1]
    end
  end
end
