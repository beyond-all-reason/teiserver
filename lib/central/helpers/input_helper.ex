defmodule Central.Helpers.InputHelper do
  @moduledoc false

  use Phoenix.HTML
  alias Phoenix.HTML.Form

  alias Central.Helpers.TimexHelper

  @human_time_info {:safe,
                    [
                      "<button tabindex='-1' type='button' class='btn btn-sm btn-info float-right' data-toggle='popover' data-placement='left' title='Human time' data-content='Human time (HT) allows you to write more natural text and the system will convert it into a date for you. Examples include: \"this tuesday at 5pm\", \"next weekday\", \"30 minutes\" and most normal UK date formats.'>HT Enabled</button>"
                    ]}

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
    type = opts[:using] || Form.input_type(form, field)

    wrapper_opts = [class: "form-group #{state_class(form, field)}"]
    label_opts = [class: "control-label"]
    input_opts = [class: "form-control"]

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
          apply(Phoenix.HTML.Form, type, [form, field, choices, input_opts])
        else
          apply(Phoenix.HTML.Form, type, [form, field, input_opts])
        end

      label = label(form, field, humanize(field), label_opts)
      description = opts[:description] || ""
      error = CentralWeb.ErrorHelpers.error_tag(form, field)
      [label, description, input, error || ""]
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

  def datetime_picker(form, field, _opts \\ []) do
    v = input_value(form, field)

    existing_value =
      cond do
        v == nil -> ""
        v == "" -> ""
        is_map(v) -> TimexHelper.date_to_str(v, :hms_dmy)
        true -> v
      end

    wrapper_opts = [class: "form-group #{state_class(form, field)}"]

    field_name = "#{form.name}[#{field}]"

    label_opts = [class: "control-label"]

    content_tag :div, wrapper_opts do
      label = label(form, field, humanize(field), label_opts)
      info = @human_time_info

      input =
        {:safe,
         [
           "<input type='text' name='",
           field_name,
           "' value='",
           existing_value,
           "' class='form-control datepicker'>"
         ]}

      error = CentralWeb.ErrorHelpers.error_tag(form, field)
      [info, label, input, error || ""]
    end
  end

  def date_picker(form, field, _opts \\ []) do
    v = input_value(form, field)

    existing_value =
      cond do
        v == nil -> ""
        v == "" -> ""
        is_map(v) -> TimexHelper.date_to_str(v, :dmy)
        true -> v
      end

    wrapper_opts = [class: "form-group #{state_class(form, field)}"]

    field_name = "#{form.name}[#{field}]"

    label_opts = [class: "control-label"]

    content_tag :div, wrapper_opts do
      label = label(form, field, humanize(field), label_opts)
      info = @human_time_info

      input =
        {:safe,
         [
           "<input type='text' name='",
           field_name,
           "' value='",
           existing_value,
           "' class='form-control datepicker'>"
         ]}

      error = CentralWeb.ErrorHelpers.error_tag(form, field)
      [info, label, input, error || ""]
    end
  end
end
