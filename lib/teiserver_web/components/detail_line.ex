defmodule TeiserverWeb.Components.DetailLine do
  @moduledoc """
  <.detail_line label="Label" value={value} />
  """
  use Phoenix.Component

  attr :label, :string, default: nil
  attr :icon, :string, default: nil
  attr :link, :map, default: nil
  attr :type, :string, default: "text"
  attr :value, :any, required: true
  attr :disabled, :boolean, default: true
  attr :suffix, :string, default: ""
  attr :width, :integer, default: nil
  attr :rows, :integer, default: 4
  attr :style, :string, default: nil

  def detail_line(assigns) do
    ~H"""
    <div class="input-group input-group-show m-1">
      <span :if={@label} class="input-group-prepend">
        <span
          class="input-group-text row-left"
          style={@width && "width: #{@width}px"}
        >
          {@label}
        </span>
      </span>

      <.render_value value={@value} type={@type} disabled={@disabled} suffix={@suffix} rows={@rows} />

      <span :if={@link} class="input-group-append">
        <a
          class={"input-group-text btn btn-#{@link.bsname} btn-sm"}
          href={@link.path}
          style="height: 100%;"
        >
          <Fontawesome.icon :if={@link.icon} icon={@link.icon} style="solid" /> &nbsp;
          <Fontawesome.icon icon="link" style="solid" />
        </a>
      </span>
    </div>
    """
  end

  attr :type, :string, required: true
  attr :value, :any, required: true
  attr :rows, :integer, default: 4
  attr :disabled, :boolean
  attr :style, :string, default: nil
  attr :suffix, :string, default: nil

  defp render_value(%{type: "textarea"} = assigns) do
    ~H"""
    <textarea
      class="form-control"
      rows={@rows}
      {@disabled && [disabled: "disabled"]}
      style={@style}
    ><%= @value %></textarea>
    """
  end

  defp render_value(%{type: "text"} = assigns) do
    ~H"""
    <input
      type="text"
      class="form-control"
      {@disabled && [disabled: "disabled"]}
      value={"#{@value}#{@suffix}"}
      style={@style}
    />
    """
  end

  defp render_value(%{type: "list"} = assigns) do
    ~H"""
    <input
      type="text"
      class="form-control"
      {@disabled && [disabled: "disabled"]}
      value={@value |> Enum.join(", ")}
      style={@style}
    />
    """
  end
end
