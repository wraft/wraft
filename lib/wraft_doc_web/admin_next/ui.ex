defmodule WraftDocWeb.AdminNext.UI do
  @moduledoc """
  Admin design system. Reusable Phoenix function components for the `/admin`
  shell — every visual surface in admin LiveViews and Backpex resource pages
  should be composed from these primitives.

  ## Philosophy

  - **Tokens, not styles.** Components take a `variant` ("primary",
    "success", …) and resolve it to design-system classes via
    `WraftDocWeb.AdminNext.UI.Tokens`. LiveViews never write
    `bg-success/15 text-success` — they pass intent.
  - **Composition over options.** Prefer slots over a long attr surface.
    A component should have one responsibility.
  - **Tailwind-safe.** All variant → class mappings are exhaustive case
    statements so Tailwind v4's class scanner sees every utility.

  ## Inventory

      <.page_header title=… description=…>
        <:eyebrow>…</:eyebrow> <:status>…</:status> <:actions>…</:actions>
      </.page_header>

      <.card title=… caption=…>
        <:header_actions>…</:header_actions>
        … body …
      </.card>

      <.stat icon=… label=… value=… footer=… delta=… accent="success">
        <:trail><.sparkline series=… accent=… /></:trail>
      </.stat>

      <.mini_stat icon=… label=… value=… />

      <.badge variant="success">approved</.badge>
      <.status_pill variant="success">All systems operational</.status_pill>

      <.button variant="primary" icon="hero-plus" navigate=…>Invite users</.button>

      <.segmented current=… event=… param=… options={[{"7D", 7}, …]} />

      <.progress_row label=… count=… max=… accent="primary" />

      <.sparkline series={[1,2,3]} accent="primary" />
      <.area_chart series=… accent=… height=… />

      <.empty_state icon=… title=… description=… />

      <.data_table>
        <:col label="Webhook">…</:col>
        <:col label="Status">…</:col>
        <:row :for={r <- @rows}>…</:row>
      </.data_table>
  """
  use Phoenix.Component

  alias Backpex.HTML.CoreComponents
  alias WraftDocWeb.AdminNext.UI.Tokens

  # ============================================================================
  # Page header
  # ============================================================================

  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :string, default: ""

  slot :eyebrow,
    doc: "Small uppercase label above the title (e.g. 'Overview', 'Workspace')."

  slot :status, doc: "Right-aligned status indicators rendered before actions."
  slot :actions, doc: "Right-aligned buttons (primary action last)."

  def page_header(assigns) do
    ~H"""
    <header class={["flex flex-col gap-3 border-b border-base-200 pb-5", @class]}>
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="min-w-0 space-y-1">
          <p :if={@eyebrow != []} class="ds-eyebrow">{render_slot(@eyebrow)}</p>
          <h1 class="ds-page-title">{@title}</h1>
        </div>
        <div
          :if={@status != [] or @actions != []}
          class="flex shrink-0 flex-wrap items-center gap-2 [&>div]:mb-0!"
        >
          {render_slot(@status)}
          {render_slot(@actions)}
        </div>
      </div>
      <p :if={@description} class="ds-page-description max-w-3xl">{@description}</p>
    </header>
    """
  end

  # ============================================================================
  # Card
  # ============================================================================

  attr :title, :string, default: nil
  attr :caption, :string, default: nil
  attr :class, :string, default: ""
  attr :body_class, :string, default: "ds-card-body"

  slot :header_actions, doc: "Right-aligned content in the card header."
  slot :footer
  slot :inner_block, required: true

  def card(assigns) do
    has_header = assigns.title || assigns.caption || assigns.header_actions != []
    assigns = assign(assigns, :has_header, has_header)

    ~H"""
    <section class={["ds-card flex flex-col", @class]}>
      <header :if={@has_header} class="ds-card-header">
        <div class="min-w-0">
          <h2 :if={@title} class="ds-section-title">{@title}</h2>
          <p :if={@caption} class="mt-0.5 ds-caption">{@caption}</p>
        </div>
        <div :if={@header_actions != []} class="shrink-0">
          {render_slot(@header_actions)}
        </div>
      </header>
      <div class={["flex-1", @body_class]}>
        {render_slot(@inner_block)}
      </div>
      <footer :if={@footer != []} class="ds-card-footer">
        {render_slot(@footer)}
      </footer>
    </section>
    """
  end

  # ============================================================================
  # Stat — headline metric with optional sparkline + delta
  # ============================================================================

  attr :icon, :string, default: nil
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :footer, :string, default: nil
  attr :delta, :any, default: nil, doc: "Signed % change. nil hides the badge."
  attr :accent, :string, default: "primary"
  attr :class, :string, default: ""

  slot :trail, doc: "Right side of value row — typically a sparkline."

  def stat(assigns) do
    ~H"""
    <section class={["ds-card", @class]}>
      <div class="ds-card-body">
        <div class="flex items-start justify-between gap-2">
          <div class="flex min-w-0 items-center gap-2 text-base-content/60">
            <CoreComponents.icon :if={@icon} name={@icon} class="size-4 shrink-0" />
            <span class="ds-metric-label truncate">{@label}</span>
          </div>
          <.delta_badge :if={@delta != nil} delta={@delta} />
        </div>
        <div class="mt-2 flex items-end justify-between gap-3">
          <p class="ds-metric-value">{@value}</p>
          <div :if={@trail != []} class="shrink-0">{render_slot(@trail)}</div>
        </div>
        <p :if={@footer} class="mt-1 ds-caption">{@footer}</p>
      </div>
    </section>
    """
  end

  attr :delta, :any, required: true

  defp delta_badge(assigns) do
    ~H"""
    <span class={["ds-badge", Tokens.badge_class(Tokens.delta_variant(@delta))]}>
      <CoreComponents.icon name={Tokens.delta_icon(@delta)} class="size-3" />
      {Tokens.format_delta(@delta)}
    </span>
    """
  end

  # ============================================================================
  # Mini stat
  # ============================================================================

  attr :icon, :string, default: nil
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :class, :string, default: ""

  def mini_stat(assigns) do
    ~H"""
    <section class={["ds-card", @class]}>
      <div class="flex items-center gap-3 ds-card-body-tight">
        <div :if={@icon} class="grid size-9 shrink-0 place-items-center rounded-md bg-base-200 text-base-content/60">
          <CoreComponents.icon name={@icon} class="size-4" />
        </div>
        <div class="min-w-0">
          <p class="ds-metric-value-sm">{@value}</p>
          <p class="mt-1 ds-caption truncate">{@label}</p>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # Badge
  # ============================================================================

  attr :variant, :string,
    default: "neutral",
    values: ~w(primary success warning error neutral ghost)

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={["ds-badge", Tokens.badge_class(@variant), @class]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ============================================================================
  # Status pill (badge + leading dot, for system-state indicators)
  # ============================================================================

  attr :variant, :string,
    default: "neutral",
    values: ~w(primary success warning error neutral)

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def status_pill(assigns) do
    ~H"""
    <span class={["ds-status-pill", Tokens.status_class(@variant), @class]}>
      <span class="ds-dot"></span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ============================================================================
  # Button — rendered as <a> if navigate/href is set, otherwise <button>
  # ============================================================================

  attr :variant, :string,
    default: "neutral",
    values: ~w(primary neutral ghost danger)

  attr :size, :string, default: "md", values: ~w(sm md)
  attr :icon, :string, default: nil
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :type, :string, default: "button"
  attr :class, :string, default: ""

  attr :rest, :global,
    include:
      ~w(phx-click phx-value-id phx-value-days phx-disable-with form name method data-confirm disabled popovertarget popovertargetaction style)

  slot :inner_block, required: true

  def button(assigns) do
    assigns = assign(assigns, :classes, button_classes(assigns))

    ~H"""
    <.link :if={@navigate} navigate={@navigate} class={@classes} {@rest}>
      <CoreComponents.icon :if={@icon} name={@icon} class={button_icon_size(@size)} />
      {render_slot(@inner_block)}
    </.link>
    <.link :if={@href && !@navigate} href={@href} class={@classes} {@rest}>
      <CoreComponents.icon :if={@icon} name={@icon} class={button_icon_size(@size)} />
      {render_slot(@inner_block)}
    </.link>
    <button :if={!@navigate && !@href} type={@type} class={@classes} {@rest}>
      <CoreComponents.icon :if={@icon} name={@icon} class={button_icon_size(@size)} />
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_classes(%{variant: v, size: s, class: c}) do
    [
      "ds-btn",
      button_variant_class(v),
      s == "sm" && "ds-btn-sm",
      c
    ]
  end

  defp button_variant_class("primary"), do: "ds-btn-primary"
  defp button_variant_class("ghost"), do: "ds-btn-ghost"
  defp button_variant_class("danger"), do: "ds-btn-danger"
  defp button_variant_class(_), do: "ds-btn-neutral"

  defp button_icon_size("sm"), do: "size-3.5"
  defp button_icon_size(_), do: "size-4"

  # ============================================================================
  # Segmented control (e.g. time-range picker)
  # ============================================================================

  attr :current, :any, required: true
  attr :options, :list, required: true, doc: "List of {label, value} tuples."
  attr :event, :string, required: true, doc: "phx-click event name."
  attr :param, :string, default: "value", doc: "phx-value-* parameter name."
  attr :class, :string, default: ""

  def segmented(assigns) do
    ~H"""
    <div role="tablist" class={["ds-segmented", @class]}>
      <button
        :for={{label, value} <- @options}
        type="button"
        role="tab"
        aria-selected={to_string(@current == value)}
        phx-click={@event}
        {[{"phx-value-#{@param}", value}]}
        class={["ds-segmented-option", @current == value && "is-active"]}
      >
        {label}
      </button>
    </div>
    """
  end

  # ============================================================================
  # Progress row (labeled linear progress bar)
  # ============================================================================

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :max, :integer, required: true
  attr :accent, :string, default: "primary"
  attr :class, :string, default: ""

  def progress_row(assigns) do
    pct = if assigns.max <= 0, do: 0, else: round(assigns.count / assigns.max * 100)
    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class={@class}>
      <div class="mb-1 flex items-center justify-between text-xs">
        <span class="font-medium text-base-content">{@label}</span>
        <span class="tabular-nums text-base-content/60">{@count}</span>
      </div>
      <div class="ds-progress-track">
        <div
          class={["ds-progress-fill", Tokens.progress_class(@accent)]}
          style={"width: #{@pct}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Sparkline (tiny SVG line + area chart)
  # ============================================================================

  attr :series, :list, required: true, doc: "Flat list of numeric values."
  attr :accent, :string, default: "primary"
  attr :class, :string, default: "h-7 w-20"

  def sparkline(%{series: []} = assigns), do: ~H""

  def sparkline(assigns) do
    {line, area} = chart_paths(assigns.series, 80, 28)

    assigns =
      assigns
      |> assign(line: line, area: area)
      |> assign(stroke: Tokens.stroke_class(assigns.accent))
      |> assign(fill: Tokens.fill_class(assigns.accent))

    ~H"""
    <svg viewBox="0 0 80 28" class={@class} preserveAspectRatio="none">
      <path d={@area} class={["opacity-[0.12]", @fill]} stroke="none" />
      <path
        d={@line}
        class={["fill-none", @stroke]}
        stroke-width="1.5"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  # ============================================================================
  # Area chart (larger SVG with x-axis labels + peak callout)
  # ============================================================================

  attr :series, :list, required: true, doc: "List of %{date: Date, count: integer}."
  attr :accent, :string, default: "primary"
  attr :height, :integer, default: 220

  def area_chart(%{series: []} = assigns) do
    ~H"""
    <p class="text-sm text-base-content/55">No data in this range.</p>
    """
  end

  def area_chart(assigns) do
    counts = Enum.map(assigns.series, & &1.count)
    width = 700
    {line, area} = chart_paths(counts, width, assigns.height)
    max_val = Enum.max(counts, fn -> 0 end)
    first = List.first(assigns.series)
    last = List.last(assigns.series)

    assigns =
      assigns
      |> assign(line: line, area: area, width: width, max_val: max_val)
      |> assign(stroke: Tokens.stroke_class(assigns.accent))
      |> assign(fill: Tokens.fill_class(assigns.accent))
      |> assign(first_date: first && first.date)
      |> assign(last_date: last && last.date)

    ~H"""
    <div class="space-y-2">
      <svg
        viewBox={"0 0 #{@width} #{@height}"}
        class="w-full"
        preserveAspectRatio="none"
        style={"height: #{@height}px"}
      >
        <line x1="0" y1="1" x2={@width} y2="1"
          class="stroke-base-200" stroke-width="1" stroke-dasharray="2 4" />
        <line x1="0" y1={@height / 2} x2={@width} y2={@height / 2}
          class="stroke-base-200" stroke-width="1" stroke-dasharray="2 4" />
        <line x1="0" y1={@height - 1} x2={@width} y2={@height - 1}
          class="stroke-base-200" stroke-width="1" />

        <path d={@area} class={["opacity-[0.12]", @fill]} stroke="none" />
        <path
          d={@line}
          class={["fill-none", @stroke]}
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
      </svg>
      <div class="flex justify-between text-[10px] text-base-content/50">
        <span>{Tokens.format_date(@first_date)}</span>
        <span class="text-base-content/40">peak {@max_val}/day</span>
        <span>{Tokens.format_date(@last_date)}</span>
      </div>
    </div>
    """
  end

  # Shared SVG path math for spark + area charts.
  defp chart_paths(series, width, height) do
    max = series |> Enum.max(fn -> 1 end) |> max(1)
    n = max(length(series) - 1, 1)
    step = width / n

    points =
      series
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        x = i * step
        y = height - v / max * (height - 2) - 1
        {x, y}
      end)

    line =
      points
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {{x, y}, i} ->
        cmd = if i == 0, do: "M", else: "L"
        "#{cmd}#{Float.round(x, 2)} #{Float.round(y, 2)}"
      end)

    area = line <> " L#{width} #{height} L0 #{height} Z"
    {line, area}
  end

  # ============================================================================
  # Empty state
  # ============================================================================

  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :string, default: ""

  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={["ds-empty", @class]}>
      <div class="ds-empty-icon">
        <CoreComponents.icon name={@icon} class="size-5" />
      </div>
      <p class="ds-empty-title">{@title}</p>
      <p :if={@description} class="ds-empty-description">{@description}</p>
      <div :if={@action != []} class="mt-2">{render_slot(@action)}</div>
    </div>
    """
  end

  # ============================================================================
  # Data table — opinionated, header + slotted rows
  # ============================================================================

  attr :class, :string, default: ""

  slot :col, required: true do
    attr :label, :string, required: true
    attr :align, :string, values: ~w(left right center)
  end

  slot :row, required: true

  def data_table(assigns) do
    ~H"""
    <div class={["overflow-x-auto", @class]}>
      <table class="ds-table">
        <thead>
          <tr>
            <th :for={c <- @col} class={col_align_class(c[:align])}>{c.label}</th>
          </tr>
        </thead>
        <tbody>
          {render_slot(@row)}
        </tbody>
      </table>
    </div>
    """
  end

  defp col_align_class("right"), do: "text-right"
  defp col_align_class("center"), do: "text-center"
  defp col_align_class(_), do: "text-left"
end
