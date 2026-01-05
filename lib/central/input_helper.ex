defmodule Central.Helpers.InputHelper do
  @moduledoc false

  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  # http://blog.plataformatec.com.br/2016/09/dynamic-forms-with-phoenix/
  def input_with_type(form, field, type) do
    input_with_type(form, field, type, [])
  end

  def input_with_type(form, field, type, opts) do
    ptype =
      case type do
        "string" -> :text_input
        "integer" -> :number_input
        "password" -> :password_input
        "text" -> :textarea
        "boolean" -> :checkbox
        "date" -> :date_select
        "datetime" -> :datetime_select
        "color" -> :color_input
        "colour" -> :color_input
        "select" -> :select
        _ -> :text_input
      end

    case ptype do
      _ -> input(form, field, opts ++ [using: ptype])
    end
  end

  def input(form, field, opts \\ []) do
    type = opts[:using]

    wrapper_opts = [class: "form-group #{state_class(form, field)}"]
    label_opts = [class: "control-label"]
    input_opts = [class: "form-control"]

    input_opts =
      input_opts ++
        case opts[:using] do
          :checkbox -> [class: "form-check-input"]
          _ -> []
        end

    # A bit messy but the best way I can think of doing it
    input_opts = input_opts ++ if opts[:autofocus], do: [autofocus: "autofocus"], else: []

    input_opts =
      input_opts ++ if opts[:placeholder], do: [placeholder: opts[:placeholder]], else: []

    input_opts = input_opts ++ if opts[:rows], do: [rows: opts[:rows]], else: []
    input_opts = input_opts ++ if opts[:columns], do: [columns: opts[:columns]], else: []

    input_opts = input_opts ++ if opts[:class], do: [class: opts[:class]], else: []

    input_opts = input_opts ++ if opts[:style], do: [style: opts[:style]], else: []

    # If choices is set to a list, that list is used as the list of choices
    # If set as a function, that function is called and :choices_arg is used as a parameter
    # the idea behind this is the arg can be passed in by the HTML template
    choices =
      if is_function(opts[:choices]) do
        opts[:choices].(opts[:choices_arg])
      else
        if opts[:choices], do: opts[:choices], else: []
      end

    content_tag :div, wrapper_opts do
      input =
        if type == :select do
          apply(PhoenixHTMLHelpers.Form, type, [form, field, choices, input_opts])
        else
          apply(PhoenixHTMLHelpers.Form, type, [form, field, input_opts])
        end

      label = label(form, field, humanize(field), label_opts)
      description = opts[:description] || ""
      error = TeiserverWeb.ErrorHelpers.error_tag(form, field)
      [label, description, input, error]
    end
  end

  defp state_class(form, field) do
    cond do
      # The form was not yet submitted
      !form.source.action -> ""
      form.errors[field] -> "has-error"
      true -> "has-success"
    end
  end

  def textarea_array(form, field, _opts \\ []) do
    raw_value =
      cond do
        is_list(input_value(form, field)) -> input_value(form, field)
        true -> [input_value(form, field)]
      end

    value = raw_value |> Enum.join("\n")

    row_count = (Enum.count(raw_value) + 2) |> max(3)

    field_name = "#{form.name}[#{field}]"

    {:safe,
     [
       "<textarea name='",
       field_name,
       "' class='form-control' rows='#{row_count}'>",
       value,
       "</textarea>"
     ]}
  end
end
