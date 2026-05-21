defmodule WraftDoc.Admin.MetricRange do
  @moduledoc """
  Shared time-window state for admin metric pages (Build Metrics, Pipeline
  Metrics).

  Encapsulates the four-preset + custom-range control used as a header
  action on each page. Returns a normalised `%__MODULE__{}` struct that the
  data modules use to bound their queries and that the LiveView uses to
  drive the segmented control / date inputs.

  A 24-hour window buckets by hour; everything else buckets by day. Custom
  ranges are clamped to a 1-year span so a misclick can't pull a
  multi-million row aggregate.
  """

  @presets [
    {"24H", "hours_24"},
    {"7D", "days_7"},
    {"30D", "days_30"},
    {"90D", "days_90"},
    {"Custom", "custom"}
  ]

  @max_custom_days 365

  defstruct preset: "days_7",
            from: nil,
            to: nil,
            bucket: :day,
            label: "Last 7 days"

  @type t :: %__MODULE__{
          preset: String.t(),
          from: DateTime.t(),
          to: DateTime.t(),
          bucket: :hour | :day,
          label: String.t()
        }

  @doc "Preset options for the segmented control as `{label, value}` tuples."
  @spec presets() :: [{String.t(), String.t()}]
  def presets, do: @presets

  @doc "Default range used on first mount — last 7 days."
  @spec default() :: t()
  def default, do: parse(%{"preset" => "days_7"})

  @doc """
  Builds a range from LiveView event params. Falls back to the default
  range on invalid input rather than raising — the UI should never break
  because someone typed an unparseable date.

  Recognised params:

  - `"preset"` — one of `"hours_24"`, `"days_7"`, `"days_30"`,
    `"days_90"`, `"custom"`.
  - `"from"` / `"to"` — ISO-8601 dates, required when preset is
    `"custom"`. Order is normalised (from <= to).
  """
  @spec parse(map()) :: t()
  def parse(params) when is_map(params) do
    case params["preset"] do
      "hours_24" -> hours(24, "Last 24 hours", :hour)
      "days_30" -> days(30, "Last 30 days")
      "days_90" -> days(90, "Last 90 days")
      "custom" -> parse_custom(params["from"], params["to"])
      _ -> days(7, "Last 7 days")
    end
  end

  defp hours(n, label, bucket) do
    now = DateTime.utc_now()
    from = DateTime.add(now, -n * 3600, :second)

    %__MODULE__{preset: "hours_#{n}", from: from, to: now, bucket: bucket, label: label}
  end

  defp days(n, label) do
    now = DateTime.utc_now()
    from = DateTime.add(now, -n * 86_400, :second)

    %__MODULE__{preset: "days_#{n}", from: from, to: now, bucket: :day, label: label}
  end

  defp parse_custom(from_str, to_str) do
    with {:ok, from_date} <- parse_date(from_str),
         {:ok, to_date} <- parse_date(to_str) do
      build_custom(from_date, to_date)
    else
      # Either date missing/invalid — keep the user on the custom preset
      # but seed today / 7 days ago so the date inputs and chart have
      # something sensible to start from. Without this, clicking the
      # "Custom" pill would silently fall back to days_7 and the URL
      # state (`?preset=custom`) would not survive a refresh or back-button.
      _ ->
        today = Date.utc_today()
        build_custom(Date.add(today, -7), today)
    end
  end

  defp build_custom(from_date, to_date) do
    {from_date, to_date} =
      if Date.compare(from_date, to_date) == :gt,
        do: {to_date, from_date},
        else: {from_date, to_date}

    from_date =
      case Date.diff(to_date, from_date) do
        d when d > @max_custom_days -> Date.add(to_date, -@max_custom_days)
        _ -> from_date
      end

    from = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")
    label = "#{Calendar.strftime(from_date, "%b %d")} – #{Calendar.strftime(to_date, "%b %d")}"

    %__MODULE__{preset: "custom", from: from, to: to, bucket: :day, label: label}
  end

  defp parse_date(str) when is_binary(str) and str != "" do
    case Date.from_iso8601(str) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp parse_date(_), do: :error

  @doc "Naive-datetime form of the lower bound, for columns typed as `naive_datetime`."
  @spec from_naive(t()) :: NaiveDateTime.t()
  def from_naive(%__MODULE__{from: from}), do: DateTime.to_naive(from)

  @doc "Naive-datetime form of the upper bound."
  @spec to_naive(t()) :: NaiveDateTime.t()
  def to_naive(%__MODULE__{to: to}), do: DateTime.to_naive(to)

  @doc "ISO-date string for the lower bound — used to pre-fill the custom date inputs."
  @spec from_date_string(t()) :: String.t()
  def from_date_string(%__MODULE__{from: from}), do: Date.to_iso8601(DateTime.to_date(from))

  @doc "ISO-date string for the upper bound."
  @spec to_date_string(t()) :: String.t()
  def to_date_string(%__MODULE__{to: to}), do: Date.to_iso8601(DateTime.to_date(to))
end
