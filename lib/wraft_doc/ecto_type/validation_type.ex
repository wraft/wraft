defmodule WraftDoc.EctoType.ValidationType do
  @moduledoc """
  An ecto type specified to store validations
  """
  use Ecto.Type

  # Custom guards we will use to validate the values
  defguardp is_non_zero_integer(value) when is_integer(value) and value > 0

  defguardp is_range(lower_limit, upper_limit)
            when is_integer(lower_limit) and is_integer(upper_limit) and lower_limit < upper_limit

  # Ecto.Type Callbacks
  def type, do: :map

  def cast(%{"rule" => "required", "value" => value} = validation) when is_boolean(value) do
    {:ok, validation}
  end

  def cast(%{"rule" => "min_length", "value" => value}) when is_non_zero_integer(value) do
    {:ok, %{"rule" => "min_length", "value" => value}}
  end

  def cast(%{"rule" => "max_length", "value" => value}) when is_non_zero_integer(value) do
    {:ok, %{"rule" => "max_length", "value" => value}}
  end

  def cast(%{"rule" => "regex", "value" => value}) when is_binary(value) do
    case Regex.compile(value) do
      {:ok, regex} -> {:ok, %{"rule" => "regex", "value" => regex}}
      {:error, _error} -> :error
    end
  end

  def cast(%{"rule" => "min_value", "value" => value} = validation) when is_integer(value) do
    {:ok, validation}
  end

  def cast(%{"rule" => "max_value", "value" => value} = validation) when is_integer(value) do
    {:ok, validation}
  end

  def cast(%{"rule" => "file_size", "value" => value}) when is_non_zero_integer(value) do
    {:ok, %{"rule" => "file_size", "value" => value}}
  end

  def cast(%{"rule" => "range", "value" => [lower_limit, upper_limit]} = validation)
      when is_range(lower_limit, upper_limit) do
    {:ok, validation}
  end

  def cast(%{"rule" => "options", "value" => value, "multiple" => truth_value} = validation)
      when is_list(value) and is_boolean(truth_value) do
    {:ok, validation}
  end

  def cast(%{"rule" => rule, "value" => value})
      when rule in ["date_max", "date_min"] and is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, %{"rule" => rule, "value" => date}}
      {:error, _} -> :error
    end
  end

  def cast(%{"rule" => "date_range", "value" => [lower_limit, upper_limit]})
      when is_binary(lower_limit) and is_binary(upper_limit) do
    with {:ok, lower} <- Date.from_iso8601(lower_limit),
         {:ok, upper} <- Date.from_iso8601(upper_limit),
         comparison when comparison in [:lt, :eq] <- Date.compare(lower, upper) do
      {:ok, %{"rule" => "date_range", "value" => [lower, upper]}}
    else
      _ -> :error
    end
  end

  def cast(%{"rule" => rule}) when rule in ["email", "url", "phone_number", "decimal", "date"] do
    {:ok, %{"rule" => rule}}
  end

  # Everything else is a failure
  def cast(_), do: :error

  # When we load validation from database, it is guaranted to be a map
  def load(%{"rule" => "regex", "value" => value}) do
    case Regex.compile(value) do
      {:ok, regex} -> {:ok, %{"rule" => "regex", "value" => regex}}
      {:error, _} -> :error
    end
  end

  def load(%{"rule" => rule, "value" => value}) when rule in ["date_max", "date_min"] do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, %{"rule" => rule, "value" => date}}
      {:error, _} -> :error
    end
  end

  def load(%{"rule" => "date_range", "value" => [lower_limit, upper_limit]}) do
    {:ok, lower} = Date.from_iso8601(lower_limit)
    {:ok, upper} = Date.from_iso8601(upper_limit)

    {:ok, %{"rule" => "date_range", "value" => [lower, upper]}}
  end

  def load(validation) when is_map(validation), do: {:ok, validation}
  def load(_), do: :error

  # When dumping validation to the database, we expect a map as the input
  # so we need to guard against them.
  def dump(validation) when is_map(validation), do: {:ok, validation}
  def dump(_), do: :error
end
