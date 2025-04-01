defmodule TeiserverWeb.Components.AssetComponents do
  use Phoenix.Component
  alias TeiserverWeb.CoreComponents, as: CC

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  # engine and game version are actually identical so use the same form.
  # when they start to diverge, this should be split
  def asset_form(assigns) do
    ~H"""
    <CC.simple_form :let={f} for={@changeset} action={@action}>
      <CC.error :if={@changeset.action}>
        Oops, something went wrong! Please check the errors below.
      </CC.error>

      <CC.input field={f[:name]} type="text" label="Name" autofocus="autofocus" />

      <:actions>
        <CC.button type="submit" class="btn-primary">{@button_label}</CC.button>
      </:actions>
    </CC.simple_form>
    """
  end
end
