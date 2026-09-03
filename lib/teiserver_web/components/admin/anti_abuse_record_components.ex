defmodule TeiserverWeb.Admin.AntiAbuseRecordComponents do
  @moduledoc false
  alias TeiserverWeb.LiveComponents.UserPicker

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents, only: [simple_form: 1, input_tw: 1]

  @doc """
  <TeiserverWeb.Admin.AntiAbuseRecordComponents.search_form
    :if={assigns[:search]}
    params={@search}
  />

  You will need to implement the following event handlers:

  handle_event("update-search", params, %Socket{} = socket)
  handle_event("validate-search", params, %Socket{} = socket)
  handle_event("reset-search", _params, %Socket{} = socket)
  """
  attr :params, :map, required: true

  def search_form(%{params: params} = assigns) do
    form = to_form(params)

    assigns =
      assigns
      |> assign(form: form)

    ~H"""
    <.simple_form for={@form} phx-change="validate-search" phx-submit="update-search">
      <div class="grid grid-flow-row-dense grid-cols-3">
        <div class="m-2">
          <div class="fieldset">
            <.live_component
              module={UserPicker}
              id="restored_by_id-user-picker"
              field={@form[:restored_by_id]}
              label="Restored by:"
            />
          </div>
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:user_id]}
            label="User ID"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:clean?]}
            label="Clean?"
            options={[{"Any", nil}, {"Clean", true}, {"Unclean", false}]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:restored?]}
            label="Restored?"
            options={[{"Any", nil}, {"Restored", true}, {"Not restored", false}]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:page_size]}
            label="Records per page"
            options={[5, 10, 25, 50]}
          />
        </div>
      </div>

      <div class="float-right">
        <div phx-click="reset-search" class="btn btn-neutral btn-soft">
          <Fontawesome.icon icon="rotate-left" style="regular" /> Reset
        </div>
        <button class="btn btn-primary btn-soft">
          <Fontawesome.icon icon="search" style="regular" /> Update results
        </button>
      </div>
    </.simple_form>
    """
  end
end
