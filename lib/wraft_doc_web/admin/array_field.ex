defmodule WraftDocWeb.Kaffy.ArrayField do
  @moduledoc """
  Custom array field for kaffy.
  """
  use Ecto.Type
  use PhoenixHTMLHelpers

  def type, do: {:array, :string}

  def cast(value) when is_binary(value) do
    result =
      value
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, result}
  end

  def cast(value) when is_list(value), do: {:ok, value}
  def cast(_), do: :error

  def load(data) when is_list(data), do: {:ok, data}
  def load(_), do: :error

  def dump(data) when is_list(data), do: {:ok, data}
  def dump(_), do: :error

  def render_form(_conn, changeset, form, field, options) do
    current_value =
      case Ecto.Changeset.get_field(changeset, field) do
        nil -> ""
        list when is_list(list) -> Enum.join(list, "\n")
        _ -> ""
      end

    Enum.reject(
      [
        {:safe, ~s(<div class="form-group">)},
        label(form, field, options[:label] || "Features"),
        textarea(form, field,
          class: "form-control",
          rows: options[:rows] || 5,
          placeholder: options[:placeholder] || "Enter each feature on a new line",
          value: current_value
        ),
        options[:help_text] &&
          {:safe, ~s(<small class="form-text text-muted">#{options[:help_text]}</small>)},
        {:safe, ~s(</div>)}
      ],
      &is_nil/1
    )
  end

  def render_index(resource, field, _options) do
    case Map.get(resource, field) do
      nil ->
        ""

      features when is_list(features) ->
        features
        |> Enum.map(&{:safe, "<div>#{&1}</div>"})
        |> Enum.intersperse({:safe, "<br>"})
    end
  end
end
