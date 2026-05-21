defmodule WraftDoc.Admin.MetricRangeTest do
  @moduledoc """
  Unit tests for the shared time-window state powering the admin
  Build Metrics and Pipeline Metrics pages.

  No DB needed — the module is pure date/struct math.
  """
  use ExUnit.Case, async: true

  alias WraftDoc.Admin.MetricRange

  describe "parse/1 presets" do
    test "no params falls back to days_7" do
      range = MetricRange.parse(%{})
      assert range.preset == "days_7"
      assert range.bucket == :day
    end

    test "unknown preset falls back to days_7 (no crash)" do
      assert MetricRange.parse(%{"preset" => "not_a_thing"}).preset == "days_7"
    end

    test "hours_24 buckets by hour" do
      range = MetricRange.parse(%{"preset" => "hours_24"})
      assert range.preset == "hours_24"
      assert range.bucket == :hour

      delta_seconds = DateTime.diff(range.to, range.from, :second)
      # ~24h, with a small tolerance for clock drift across calls
      assert_in_delta delta_seconds, 24 * 3600, 5
    end

    test "days_30 spans ~30 days and buckets by day" do
      range = MetricRange.parse(%{"preset" => "days_30"})
      assert range.preset == "days_30"
      assert range.bucket == :day

      delta_seconds = DateTime.diff(range.to, range.from, :second)
      assert_in_delta delta_seconds, 30 * 86_400, 5
    end

    test "default/0 matches the bare-params parse" do
      assert MetricRange.default().preset == "days_7"
    end
  end

  describe "parse/1 custom" do
    test "valid ISO dates produce a custom range" do
      range =
        MetricRange.parse(%{
          "preset" => "custom",
          "from" => "2026-05-01",
          "to" => "2026-05-15"
        })

      assert range.preset == "custom"
      assert DateTime.to_date(range.from) == ~D[2026-05-01]
      assert DateTime.to_date(range.to) == ~D[2026-05-15]
    end

    test "swaps from/to when from > to" do
      range =
        MetricRange.parse(%{
          "preset" => "custom",
          "from" => "2026-05-15",
          "to" => "2026-05-01"
        })

      assert DateTime.to_date(range.from) == ~D[2026-05-01]
      assert DateTime.to_date(range.to) == ~D[2026-05-15]
    end

    test "clamps to a 1-year span when the range is too wide" do
      range =
        MetricRange.parse(%{
          "preset" => "custom",
          "from" => "2020-01-01",
          "to" => "2026-05-21"
        })

      # to is kept; from is pulled forward to to - 365d
      assert DateTime.to_date(range.to) == ~D[2026-05-21]
      assert Date.diff(DateTime.to_date(range.to), DateTime.to_date(range.from)) == 365
    end

    test "missing dates seed last 7 days but keep preset=custom (regression: prior code fell back to days_7)" do
      range = MetricRange.parse(%{"preset" => "custom"})

      assert range.preset == "custom"
      assert range.bucket == :day

      span_days = Date.diff(DateTime.to_date(range.to), DateTime.to_date(range.from))
      assert span_days == 7
    end

    test "invalid date strings seed last 7 days but keep preset=custom" do
      range =
        MetricRange.parse(%{"preset" => "custom", "from" => "not-a-date", "to" => "garbage"})

      assert range.preset == "custom"

      span_days = Date.diff(DateTime.to_date(range.to), DateTime.to_date(range.from))
      assert span_days == 7
    end

    test "the to bound captures the full end-of-day" do
      range =
        MetricRange.parse(%{
          "preset" => "custom",
          "from" => "2026-05-01",
          "to" => "2026-05-01"
        })

      assert NaiveDateTime.compare(MetricRange.from_naive(range), ~N[2026-05-01 00:00:00]) == :eq
      assert NaiveDateTime.compare(MetricRange.to_naive(range), ~N[2026-05-01 23:59:59]) == :eq
    end
  end

  describe "date-string helpers" do
    test "from_date_string / to_date_string round-trip a custom range" do
      params = %{"preset" => "custom", "from" => "2026-03-10", "to" => "2026-04-20"}

      range = MetricRange.parse(params)
      assert MetricRange.from_date_string(range) == "2026-03-10"
      assert MetricRange.to_date_string(range) == "2026-04-20"

      # Re-parsing the same strings reproduces the same dates
      round_trip =
        MetricRange.parse(%{
          "preset" => "custom",
          "from" => MetricRange.from_date_string(range),
          "to" => MetricRange.to_date_string(range)
        })

      assert MetricRange.from_date_string(round_trip) == "2026-03-10"
      assert MetricRange.to_date_string(round_trip) == "2026-04-20"
    end
  end

  describe "presets/0" do
    test "exposes the segmented-control options" do
      labels = MetricRange.presets() |> Enum.map(fn {label, _v} -> label end)
      values = MetricRange.presets() |> Enum.map(fn {_l, value} -> value end)

      assert "24H" in labels
      assert "Custom" in labels
      assert "hours_24" in values
      assert "custom" in values
    end
  end
end
