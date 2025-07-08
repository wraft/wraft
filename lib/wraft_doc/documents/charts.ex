defmodule WraftDoc.Documents.Charts do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """

  import Ecto.Query
  require Logger

  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo

  @valid_combinations %{
    "day" => ["hour", "day"],
    "week" => ["hour", "day"],
    "month" => ["day", "week"],
    "year" => ["day", "week", "month"],
    "alltime" => ["week", "month", "year"],
    "custom" => ["hour", "day", "week", "month", "year"]
  }

  @spec get_contract_chart(map(), map()) ::
          {:ok, list()} | {:error, String.t()}
  def get_contract_chart(current_user, params \\ %{}) do
    with {:ok, normalized_params} <- normalize_params(params),
         {:ok, _} <-
           validate_period_interval_combination(
             normalized_params.period,
             normalized_params.interval
           ),
         {:ok, _} <- validate_custom_period_dates(normalized_params),
         {:ok, _} <- validate_custom_period_interval(normalized_params),
         {:ok, contracts} <-
           fetch_contracts_by_period(
             current_user,
             normalized_params.period,
             normalized_params.select_by,
             normalized_params
           ),
         {:ok, grouped_data} <- group_by_interval(contracts, normalized_params.interval) do
      {:ok, grouped_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_params(params) do
    normalized = %{
      period: Map.get(params, "period", "month"),
      doc_type: Map.get(params, "doc_type", "both"),
      interval: Map.get(params, "interval", "week"),
      select_by: Map.get(params, "select_by", "insert"),
      from: Map.get(params, "from"),
      to: Map.get(params, "to")
    }

    if normalized.select_by in ["insert", "update"] do
      {:ok, normalized}
    else
      {:error, "Invalid select_by parameter. Must be 'insert' or 'update'"}
    end
  end

  defp validate_period_interval_combination(period, interval) do
    @valid_combinations
    |> Map.get(period)
    |> case do
      nil ->
        {:error,
         "Invalid period '#{period}'. Allowed periods: #{@valid_combinations |> Map.keys() |> Enum.join(", ")}"}

      allowed_intervals ->
        if interval in allowed_intervals do
          {:ok, :valid}
        else
          {:error,
           "Invalid interval '#{interval}' for period '#{period}'. Allowed intervals: #{Enum.join(allowed_intervals, ", ")}"}
        end
    end
  end

  defp validate_custom_period_dates(%{period: "custom", from: from, to: to})
       when from != nil and to != nil do
    with {:ok, from_datetime} <- parse_datetime(from),
         {:ok, to_datetime} <- parse_datetime(to),
         :ok <- validate_date_range(from_datetime, to_datetime) do
      {:ok, :valid}
    else
      {:error, reason} ->
        {:error, reason}

      :error ->
        {:error, "Invalid datetime format. Use ISO8601 format (e.g., '2024-04-01T08:00:00Z')"}
    end
  end

  defp validate_custom_period_dates(%{period: "custom"}),
    do: {:error, "Custom period requires both 'from' and 'to' datetime parameters"}

  defp validate_custom_period_dates(_params), do: {:ok, :valid}

  defp validate_custom_period_interval(%{
         period: "custom",
         from: from,
         to: to,
         interval: interval
       })
       when from != nil and to != nil do
    with {:ok, from_datetime} <- parse_datetime(from),
         {:ok, to_datetime} <- parse_datetime(to),
         {:ok, _} <- validate_custom_interval(from_datetime, to_datetime, interval) do
      {:ok, :valid}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_custom_period_interval(_params), do: {:ok, :valid}

  defp parse_datetime(nil), do: {:error, "from/to parameter is required"}

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    datetime_str
    |> DateTime.from_iso8601()
    |> case do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _} ->
        datetime_str
        |> NaiveDateTime.from_iso8601()
        |> case do
          {:ok, naive_datetime} ->
            {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}

          {:error, _} ->
            {:error, "Invalid datetime format. Use ISO8601 format"}
        end
    end
  end

  defp parse_datetime(_), do: {:error, "Datetime must be a string"}

  defp validate_date_range(from_datetime, to_datetime) do
    now = DateTime.utc_now()

    cond do
      DateTime.compare(from_datetime, to_datetime) == :gt ->
        {:error, "From date cannot be greater than to date"}

      DateTime.compare(from_datetime, now) == :gt ->
        {:error, "From date cannot be in the future"}

      true ->
        :ok
    end
  end

  defp validate_custom_interval(from_datetime, to_datetime, interval) do
    diff_days =
      to_datetime
      |> DateTime.diff(from_datetime, :second)
      |> div(86_400)

    case interval do
      "hour" when diff_days > 31 ->
        {:error, "Hour interval not recommended for date ranges longer than 31 days"}

      "day" when diff_days > 365 ->
        {:error, "Day interval not recommended for date ranges longer than 365 days"}

      "week" when diff_days < 7 ->
        {:error, "Week interval requires at least 7 days between from and to dates"}

      "month" when diff_days < 31 ->
        {:error, "Month interval requires at least 31 days between from and to dates"}

      _ ->
        {:ok, :valid}
    end
  end

  defp fetch_contracts_by_period(
         %{current_org_id: org_id} = _current_user,
         period,
         select_by,
         params
       ) do
    # TODO: Add organisation_id in instance and remove join query.

    base_query =
      Instance
      |> where([i], i.organisation_id == ^org_id)
      |> filter_by_doc_type(params["doc_type"])

    query =
      case period do
        "alltime" -> base_query
        "custom" -> build_custom_period_query(base_query, select_by, params)
        _ -> build_period_query(base_query, period, select_by)
      end

    case Repo.all(query) do
      contracts when is_list(contracts) -> {:ok, contracts}
      {:error, reason} -> {:error, "Database error: #{reason}"}
    end
  rescue
    e -> {:error, "Database error: #{Exception.message(e)}"}
  end

  defp build_custom_period_query(base_query, select_by, %{from: from, to: to}) do
    with {:ok, from_datetime} <- parse_datetime(from),
         {:ok, to_datetime} <- parse_datetime(to) do
      date_field = if select_by == "insert", do: :inserted_at, else: :updated_at

      from(i in base_query,
        where:
          field(i, ^date_field) >= ^DateTime.to_naive(from_datetime) and
            field(i, ^date_field) <= ^DateTime.to_naive(to_datetime)
      )
    else
      _ -> base_query
    end
  end

  defp build_period_query(base_query, period, select_by) do
    period
    |> get_period_date_range()
    |> case do
      {:ok, {start_date, end_date}} ->
        date_field = if select_by == "insert", do: :inserted_at, else: :updated_at

        from(i in base_query,
          where: field(i, ^date_field) >= ^start_date and field(i, ^date_field) <= ^end_date
        )

      {:error, _} ->
        base_query
    end
  end

  defp get_period_date_range(period) do
    now = DateTime.utc_now()

    case period do
      "day" ->
        start_of_day = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
        end_of_day = DateTime.new!(Date.utc_today(), ~T[23:59:59], "Etc/UTC")
        {:ok, {DateTime.to_naive(start_of_day), DateTime.to_naive(end_of_day)}}

      "week" ->
        seven_days_ago = DateTime.add(now, -7, :day)
        start_of_period = DateTime.new!(DateTime.to_date(seven_days_ago), ~T[00:00:00], "Etc/UTC")
        {:ok, {DateTime.to_naive(start_of_period), DateTime.to_naive(now)}}

      "month" ->
        start_of_month =
          DateTime.new!(Date.beginning_of_month(Date.utc_today()), ~T[00:00:00], "Etc/UTC")

        end_of_month = DateTime.new!(Date.end_of_month(Date.utc_today()), ~T[23:59:59], "Etc/UTC")
        {:ok, {DateTime.to_naive(start_of_month), DateTime.to_naive(end_of_month)}}

      "year" ->
        today = Date.utc_today()

        start_of_year =
          DateTime.new!(%Date{year: today.year, month: 1, day: 1}, ~T[00:00:00], "Etc/UTC")

        end_of_year =
          DateTime.new!(%Date{year: today.year, month: 12, day: 31}, ~T[23:59:59], "Etc/UTC")

        {:ok, {DateTime.to_naive(start_of_year), DateTime.to_naive(end_of_year)}}

      _ ->
        {:error, "Invalid period"}
    end
  end

  defp group_by_interval(contracts, interval) do
    contracts
    |> Enum.group_by(&format_datetime_for_interval(&1.inserted_at, interval))
    |> Enum.map(fn {datetime, contracts_in_interval} ->
      calculate_interval_metrics(datetime, contracts_in_interval)
    end)
    |> Enum.sort_by(& &1.datetime)
    |> then(&{:ok, &1})
  rescue
    e -> {:error, "Grouping error: #{Exception.message(e)}"}
  end

  defp calculate_interval_metrics(datetime, contracts) do
    total = length(contracts)
    confirmed = count_confirmed_contracts(contracts)
    pending = total - confirmed

    %{
      datetime: datetime,
      total: total,
      total_amount:
        Enum.sum(
          Enum.map(contracts, fn contract ->
            case contract.meta do
              %{amount: amount} -> amount
              _ -> 0
            end
          end)
        ),
      confirmed: confirmed,
      pending: pending
    }
  end

  defp filter_by_doc_type(query, "contract") do
    from(i in query,
      where: fragment("?->>'type' = ?", i.meta, "contract")
    )
  end

  defp filter_by_doc_type(query, "document") do
    from(i in query,
      where: fragment("?->>'type' = ?", i.meta, "document")
    )
  end

  defp filter_by_doc_type(query, _), do: query

  defp count_confirmed_contracts(contracts), do: Enum.count(contracts, & &1.approval_status)

  defp format_datetime_for_interval(naive_datetime, interval) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")

    case interval do
      "hour" ->
        datetime
        |> DateTime.truncate(:second)
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> DateTime.to_iso8601()

      "day" ->
        datetime
        |> DateTime.to_date()
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()

      "week" ->
        datetime
        |> DateTime.to_date()
        |> Date.beginning_of_week(:monday)
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()

      "month" ->
        datetime
        |> DateTime.to_date()
        |> Date.beginning_of_month()
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()

      "year" ->
        date = DateTime.to_date(datetime)

        %Date{year: date.year, month: 1, day: 1}
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()
    end
  end
end
