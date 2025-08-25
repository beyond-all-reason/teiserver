defmodule TeiserverWeb.PaginationComponents do
  @moduledoc """
  Pagination components and utilities.
  """
  use Phoenix.Component


  @doc """
  Renders a pagination component with page numbers and navigation.
  
  ## Examples
      
      <.pagination
        page={@page}
        total_pages={@total_pages}
        base_url={~p"/admin/users"}
        class="mt-3"
      />
      
  ## Options
      
  * `:page` - Current page number (0-based)
  * `:total_pages` - Total number of pages (required for page number display)
  * `:base_url` - Base URL for pagination links
  * `:class` - Additional CSS classes
  * `:page_size` - Number of items per page (for display purposes)
  * `:total_count` - Total number of items (for display purposes)
  * `:current_count` - Number of items on current page
  * `:show_go_to` - Whether to show "go to page" input (default: true)
  * `:max_pages` - Maximum number of page links to show (default: 7)
  * `:show_limit_dropdown` - Whether to show limit dropdown (default: true)
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :base_url, :string, required: true
  attr :class, :string, default: ""
  attr :page_size, :integer, default: nil
  attr :total_count, :integer, default: nil
  attr :current_count, :integer, default: nil
  attr :show_go_to, :boolean, default: true
  attr :show_limit_dropdown, :boolean, default: true
  attr :max_pages, :integer, default: 7

  def pagination(assigns) do
    assigns = assign(assigns, :page_range, build_page_range(assigns.page, assigns.total_pages, assigns.max_pages))
    
    ~H"""
    <div class={"row mt-3 #{@class}"}>
      <div class="col-md-6">
        <!-- Info Section -->
        <%= if @page_size != nil and @total_count != nil and @current_count != nil do %>
          <div class="text-muted">
            Showing <%= @page * @page_size + 1 %>-<%= @page * @page_size + @current_count %> of <%= @total_count %>
          </div>
        <% end %>
      </div>
      
      <div class="col-md-6">
        <div class="d-flex justify-content-end align-items-center">
          <!-- Limit Dropdown -->
          <%= if @show_limit_dropdown and @page_size != nil do %>
            <div class="me-3">
              <div class="input-group input-group-sm" style="width: 130px;">
                <span class="input-group-text">Show</span>
                <select 
                  class="form-select" 
                  onchange={"var url = window.location.href; url = url.replace(/[?&]limit=[^&]*/g, ''); url = url.replace(/[?&]page=[^&]*/g, ''); url = url.replace(/\\?&/, '?').replace(/\\?$/, ''); var separator = url.indexOf('?') !== -1 ? '&' : '?'; url += separator + 'limit=' + this.value + '&page=1'; window.location.href = url;"}
                >
                  <option value="10" selected={@page_size == 10}>10</option>
                  <option value="25" selected={@page_size == 25}>25</option>
                  <option value="50" selected={@page_size == 50}>50</option>
                  <option value="100" selected={@page_size == 100}>100</option>
                </select>
              </div>
            </div>
          <% end %>

          <!-- Go to Page Input -->
          <%= if @show_go_to and @total_pages > 5 do %>
            <div class="me-3">
              <div class="input-group input-group-sm" style="width: 140px;">
                <span class="input-group-text">Go to</span>
                <input 
                  type="number" 
                  class="form-control" 
                  placeholder="Page" 
                  min="1" 
                  max={@total_pages}
                  onkeypress={"if(event.key==='Enter'){window.location.href='#{@base_url}#{if String.contains?(@base_url, "?"), do: "&", else: "?"}page='+parseInt(this.value)}"}
                >
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
                    <.link navigate={"#{@base_url}#{if String.contains?(@base_url, "?"), do: "&", else: "?"}page=#{@page}"} class="page-link">
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
                          <%= page_num + 1 %>
                          <span class="visually-hidden">(current)</span>
                        </span>
                      <% else %>
                        <.link navigate={"#{@base_url}#{if String.contains?(@base_url, "?"), do: "&", else: "?"}page=#{page_num + 1}"} class="page-link">
                          <%= page_num + 1 %>
                        </.link>
                      <% end %>
                    </li>
                  <% end %>
                <% end %>
                
                <!-- Next Button -->
                <li class={"page-item #{if @page >= @total_pages - 1, do: "disabled"}"}>
                  <%= if @page < @total_pages - 1 do %>
                    <.link navigate={"#{@base_url}#{if String.contains?(@base_url, "?"), do: "&", else: "?"}page=#{@page + 2}"} class="page-link">
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
  Builds a pagination URL that includes only specified parameters.
  
  ## Options
  
  * `conn` - The connection
  * `params` - All available parameters
  * `include_params` - List of parameter names to include (defaults to empty list)
  """
  def build_pagination_url(conn, params, include_params \\ []) do
    # Include only specified parameters and build query string
    search_params = 
      params
      |> Map.take(include_params)
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")
    
    base_path = conn.request_path
    
    if search_params == "" do
      base_path
    else
      "#{base_path}?#{search_params}"
    end
  end





  # Helper function to build the page range for pagination
  # Returns a list like [0, 1, :ellipsis, 5, 6, 7] for smart pagination
  defp build_page_range(_current_page, total_pages, max_pages) when total_pages <= max_pages do
    # If total pages is small, show all pages
    Enum.to_list(0..(total_pages - 1))
  end

  defp build_page_range(current_page, total_pages, max_pages) do
    # Smart pagination with ellipsis
    half = div(max_pages - 3, 2) # Reserve space for first, last, and ellipsis
    
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
