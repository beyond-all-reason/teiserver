defmodule TeiserverWeb.Components.OAuthApplicationComponent do
  use Phoenix.Component
  alias TeiserverWeb.CoreComponents, as: CC

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def application_form(assigns) do
    ~H"""
    <CC.simple_form :let={f} for={@changeset} action={@action}>
      <CC.error :if={@changeset.action}>
        Oops, something went wrong! Please check the errors below.
      </CC.error>

      <CC.input field={f[:name]} type="text" label="Name (user facing)" />
      <CC.input field={f[:uid]} type="text" label="client id" />

      <br />
      <p><strong>List of scopes</strong></p>
      <CC.error :if={@changeset.errors[:scopes]}>
        <% {msg, _} = @changeset.errors[:scopes] %>
        {msg}
      </CC.error>

      <%= for {scope, checked, desc} <- @scopes do %>
        <p>
          <CC.input
            type="checkbox"
            value="true"
            name={"scopes[#{scope}]"}
            id={"application_scope_#{scope}"}
            checked={checked}
            label={scope}
            description={desc}
          />
        </p>
      <% end %>

      <p>
        Note that changing scopes there will <strong>NOT</strong>
        change any authorization code, access token or client credentials
      </p>

      <%!-- This form is meant to be used by an admin user, so it's fine to allow supplying --%>
      <%!-- an email manually. If given to general users, it's probably best to lock that down --%>
      <%!-- to the email of the logged-in user only. --%>
      <CC.input field={f[:owner_email]} type="email" label="owner email" />
      <CC.input
        field={Map.update(f[:redirect_uris], :value, "", &Enum.join(&1, ", "))}
        type="text"
        label="comma separated redirect uris"
      />
      <CC.input field={f[:description]} type="text" label="short description" />
      <:actions>
        <CC.button type="submit" class="btn-primary">{@button_label}</CC.button>
      </:actions>
    </CC.simple_form>
    """
  end
end
