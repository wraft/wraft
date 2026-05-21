defmodule WraftDocWeb.AdminNext.UI.Tokens do
  @moduledoc """
  Semantic-to-visual mapping helpers for the admin design system.

  Translates domain concepts (waiting-list status, webhook health, delta
  direction) into design-system **variant** strings (`"primary"`,
  `"success"`, `"warning"`, `"error"`, `"neutral"`). Components in
  `WraftDocWeb.AdminNext.UI` consume these variants and render the right
  tokens — keeping LiveViews free of presentation logic.

  Also exposes value formatters (dates, deltas, plan labels) so every page
  renders them identically.
  """

  @type variant :: String.t()

  # ----- Waiting list status -----

  @spec status_variant(atom() | any()) :: variant()
  def status_variant(:approved), do: "success"
  def status_variant(:rejected), do: "error"
  def status_variant(:pending), do: "warning"
  def status_variant(_), do: "neutral"

  # ----- Webhook health -----

  @spec webhook_variant(map()) :: variant()
  def webhook_variant(%{total: 0}), do: "neutral"
  def webhook_variant(%{success_rate: r}) when r >= 99.0, do: "success"
  def webhook_variant(%{success_rate: r}) when r >= 90.0, do: "warning"
  def webhook_variant(_), do: "error"

  @spec webhook_label(map()) :: String.t()
  def webhook_label(%{total: 0}), do: "No traffic"
  def webhook_label(%{success_rate: r}) when r >= 99.0, do: "All systems operational"
  def webhook_label(%{success_rate: r}) when r >= 90.0, do: "Some failures"
  def webhook_label(_), do: "Degraded"

  # ----- Delta (week-over-week change) -----

  @spec delta_variant(number() | nil) :: variant()
  def delta_variant(d) when is_number(d) and d > 0, do: "success"
  def delta_variant(d) when is_number(d) and d < 0, do: "error"
  def delta_variant(_), do: "neutral"

  @spec delta_icon(number() | nil) :: String.t()
  def delta_icon(d) when is_number(d) and d >= 0, do: "hero-arrow-trending-up"
  def delta_icon(_), do: "hero-arrow-trending-down"

  @spec delta_text_class(number() | nil) :: String.t()
  def delta_text_class(d) when is_number(d) and d > 0, do: "text-success"
  def delta_text_class(d) when is_number(d) and d < 0, do: "text-error"
  def delta_text_class(_), do: "text-base-content/60"

  @spec format_delta(number() | nil) :: String.t()
  def format_delta(d) when is_number(d) do
    sign = if d > 0, do: "+", else: ""
    "#{sign}#{d}%"
  end

  def format_delta(_), do: ""

  # ----- Plan labels -----

  @spec plan_label(atom() | String.t() | nil) :: String.t()
  def plan_label(:free), do: "Free"
  def plan_label(:regular), do: "Regular"
  def plan_label(:enterprise), do: "Enterprise"
  def plan_label(nil), do: "Untyped"
  def plan_label(""), do: "Untyped"
  def plan_label(other), do: other |> to_string() |> String.capitalize()

  # ----- Date / datetime formatters -----

  @spec format_date(Date.t() | nil) :: String.t()
  def format_date(nil), do: "—"
  def format_date(%Date{} = d), do: Calendar.strftime(d, "%b %d")

  @spec format_datetime(NaiveDateTime.t() | DateTime.t() | nil) :: String.t()
  def format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %H:%M")
  def format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %H:%M")
  def format_datetime(_), do: "—"

  # ----- Variant → Tailwind class helpers -----
  #
  # Tailwind v4 needs the full class string visible at compile time, so we
  # enumerate the variants exhaustively rather than interpolating.

  @doc "SVG stroke class for the given variant."
  @spec stroke_class(variant()) :: String.t()
  def stroke_class("primary"), do: "stroke-primary"
  def stroke_class("success"), do: "stroke-success"
  def stroke_class("warning"), do: "stroke-warning"
  def stroke_class("error"), do: "stroke-error"
  def stroke_class(_), do: "stroke-base-content/50"

  @doc "SVG fill class for the given variant."
  @spec fill_class(variant()) :: String.t()
  def fill_class("primary"), do: "fill-primary"
  def fill_class("success"), do: "fill-success"
  def fill_class("warning"), do: "fill-warning"
  def fill_class("error"), do: "fill-error"
  def fill_class(_), do: "fill-base-content/50"

  @doc "Badge class for the given variant. Used by `UI.badge/1`."
  @spec badge_class(variant()) :: String.t()
  def badge_class("primary"), do: "ds-badge-primary"
  def badge_class("success"), do: "ds-badge-success"
  def badge_class("warning"), do: "ds-badge-warning"
  def badge_class("error"), do: "ds-badge-error"
  def badge_class("ghost"), do: "ds-badge-ghost"
  def badge_class(_), do: "ds-badge-neutral"

  @doc "Status-pill class for the given variant. Used by `UI.status_pill/1`."
  @spec status_class(variant()) :: String.t()
  def status_class("primary"), do: "ds-status-primary"
  def status_class("success"), do: "ds-status-success"
  def status_class("warning"), do: "ds-status-warning"
  def status_class("error"), do: "ds-status-error"
  def status_class(_), do: "ds-status-neutral"

  @doc "Progress-bar fill class for the given variant."
  @spec progress_class(variant()) :: String.t()
  def progress_class("primary"), do: "ds-progress-fill-primary"
  def progress_class("success"), do: "ds-progress-fill-success"
  def progress_class("warning"), do: "ds-progress-fill-warning"
  def progress_class("error"), do: "ds-progress-fill-error"
  def progress_class(_), do: "ds-progress-fill-neutral"
end
