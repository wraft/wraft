defmodule WraftDocWeb.AdminNext.EnterprisePlanLive do
  @moduledoc """
  Backpex admin for custom (`custom IS NOT NULL`) `WraftDoc.Enterprise.Plan` rows
  — the "Enterprise" variant managed separately from the regular Plan admin.

  Form is organised into four panels — **Basics**, **Features**,
  **Limits & entitlements**, and **Custom contract** — mirroring `PlanLive`
  with the addition of the `custom` embed (frequency / period / end date).

  Mirrors `WraftDocWeb.EnterprisePlanAdmin` (Kaffy). Same Paddle/embed
  limitations as `PlanLive`: row CRUD only, no PaddleAPI sync from this UI.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Enterprise.Plan,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Custom (non-public) plans for enterprise contracts."

  import Ecto.Query

  alias Backpex.HTML.Form, as: BackpexForm
  alias Backpex.HTML.Layout
  alias WraftDoc.Enterprise.Plan
  alias WraftDocWeb.AdminNext.PlanLive

  @impl Backpex.LiveResource
  def singular_name, do: "Enterprise Plan"

  @impl Backpex.LiveResource
  def plural_name, do: "Enterprise Plans"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def panels do
    # `features_panel` has its label suppressed (nil) because the features field
    # renders its own section header with the "+ Add feature" button.
    [
      features_panel: nil,
      limits_panel: "Limits & entitlements",
      custom_panel: "Custom contract"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      # ── Basics ───────────────────────────────────────────────────────
      name: %{
        module: Backpex.Fields.Text,
        label: "Plan name",
        placeholder: "e.g. Acme Corp",
        searchable: true,
        orderable: true
      },
      description: %{
        module: Backpex.Fields.Textarea,
        label: "Description",
        placeholder: "Short description for internal reference",
        rows: 2
      },
      organisation: %{
        module: Backpex.Fields.BelongsTo,
        label: "Organisation",
        display_field: :name,
        live_resource: WraftDocWeb.AdminNext.OrganisationLive
      },
      billing_interval: %{
        module: Backpex.Fields.Select,
        label: "Billing interval",
        options: [{"Monthly", :month}, {"Yearly", :year}, {"Custom", :custom}]
      },
      trial_period: %{
        module: Backpex.Fields.Text,
        label: "Trial length",
        only: [:new, :edit, :show, :index],
        render: fn assigns ->
          ~H"<span>{WraftDocWeb.AdminNext.PlanLive.trial_period_label(@value)}</span>"
        end,
        render_form: &PlanLive.render_trial_length_form/1
      },
      payment_link: %{
        module: Backpex.Fields.Text,
        label: "Pay link",
        placeholder: "https://buy.paddle.com/…"
      },
      plan_amount: %{
        module: Backpex.Fields.Text,
        label: "Amount",
        except: [:new, :edit]
      },
      currency: %{
        module: Backpex.Fields.Text,
        label: "Currency",
        except: [:new, :edit]
      },
      is_active?: %{
        module: Backpex.Fields.Boolean,
        label: "Active",
        orderable: true,
        except: [:new, :edit],
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-success/10 text-success",
            !@value && "bg-error/10 text-error"
          ]}>
            {if @value, do: "Active", else: "Inactive"}
          </span>
          """
        end
      },

      # ── Features ─────────────────────────────────────────────────────
      features: %{
        module: Backpex.Fields.Text,
        label: "Features",
        panel: :features_panel,
        only: [:new, :edit, :show],
        render: fn assigns ->
          ~H'<span>{(@value || []) |> Enum.join(", ")}</span>'
        end,
        render_form: &PlanLive.render_features_form/1
      },

      # ── Limits & entitlements ────────────────────────────────────────
      limits: %{
        module: Backpex.Fields.Text,
        label: "Quotas",
        panel: :limits_panel,
        only: [:new, :edit, :show],
        render: fn assigns ->
          ~H'<span class="font-mono text-xs">{WraftDocWeb.AdminNext.PlanLive.embed_label(@value)}</span>'
        end,
        render_form: &PlanLive.render_limits_form/1
      },

      # ── Custom contract ──────────────────────────────────────────────
      custom: %{
        module: Backpex.Fields.Text,
        label: "Contract terms",
        panel: :custom_panel,
        only: [:new, :edit, :show],
        render: fn assigns ->
          ~H"<span>{WraftDocWeb.AdminNext.EnterprisePlanLive.custom_period_label(@value)}</span>"
        end,
        render_form: &__MODULE__.render_custom_form/1
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Keyword.delete(default_actions, :delete) ++
      [delete: %{module: WraftDocWeb.AdminNext.PlanLive.SoftDeactivate}]
  end

  def item_query(query, _live_action, _assigns) do
    from(p in query,
      where: not is_nil(p.custom),
      where: p.is_active? == true,
      preload: [:coupon, :creator, :organisation]
    )
  end

  def changeset(plan, attrs, _metadata) do
    Plan.custom_plan_changeset(
      plan,
      attrs |> normalize_features() |> normalize_trial_period() |> normalize_custom()
    )
  end

  # Same shape as PlanLive: features arrives as a list under `change[features][]`.
  # Trim and drop blanks so empty editing rows don't persist.
  defp normalize_features(%{"features" => features} = attrs) when is_list(features) do
    list = features |> Enum.map(&String.trim(to_string(&1))) |> Enum.reject(&(&1 == ""))
    Map.put(attrs, "features", list)
  end

  defp normalize_features(attrs), do: attrs

  # Drop the trial_period embed entirely when the frequency input is blank so
  # `cast_embed` leaves `trial_period: nil` instead of building a stub with only
  # `period: :day` set. Keep only the fields the embed cares about.
  defp normalize_trial_period(%{"trial_period" => %{"frequency" => freq} = tp} = attrs) do
    if String.trim(to_string(freq)) == "" do
      Map.delete(attrs, "trial_period")
    else
      Map.put(attrs, "trial_period", Map.take(tp, ["frequency", "period"]))
    end
  end

  defp normalize_trial_period(attrs), do: attrs

  # `<input type="datetime-local">` submits `2026-05-21T14:30` (no seconds, no
  # timezone) which `Ecto.Type.cast/2` rejects for `:utc_datetime`. Append `:00Z`
  # so the cast succeeds and the value lands as UTC.
  defp normalize_custom(%{"custom" => %{} = custom} = attrs) do
    custom =
      case Map.get(custom, "end_date") do
        nil -> custom
        "" -> custom
        value -> Map.put(custom, "end_date", normalize_end_date(value))
      end

    Map.put(attrs, "custom", custom)
  end

  defp normalize_custom(attrs), do: attrs

  defp normalize_end_date(value) when is_binary(value) do
    cond do
      String.ends_with?(value, "Z") -> value
      Regex.match?(~r/T\d{2}:\d{2}$/, value) -> value <> ":00Z"
      Regex.match?(~r/T\d{2}:\d{2}:\d{2}(\.\d+)?$/, value) -> value <> "Z"
      true -> value
    end
  end

  defp normalize_end_date(value), do: value

  @doc "Human label for a `Plan.Custom` embed (e.g. `2 years · ends 2027-01-01`)."
  def custom_period_label(nil), do: "—"

  def custom_period_label(%{
        custom_period_frequency: freq,
        custom_period: period,
        end_date: end_date
      })
      when not is_nil(freq) and not is_nil(period) do
    unit = period |> to_string() |> pluralize(freq)
    base = "#{freq} #{unit}"

    case end_date do
      %DateTime{} = dt -> base <> " · ends " <> Calendar.strftime(dt, "%Y-%m-%d")
      _ -> base
    end
  end

  def custom_period_label(_), do: "—"

  defp pluralize(unit, 1), do: unit
  defp pluralize(unit, _n), do: unit <> "s"

  # ─── Custom form renderers ──────────────────────────────────────────────

  @doc false
  # Custom contract embed: frequency (number), period (select), end_date
  # (datetime-local). All three are required by `Plan.Custom.changeset/2`.
  def render_custom_form(assigns) do
    ~H"""
    <div class="px-6 py-2">
      <.inputs_for :let={cf} field={@form[@name]}>
        <div class="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-3">
          <div>
            <Layout.input_label for={cf[:custom_period_frequency]} text="Frequency" />
            <BackpexForm.input
              type="number"
              field={cf[:custom_period_frequency]}
              placeholder="1"
              min="1"
            />
          </div>
          <div>
            <Layout.input_label for={cf[:custom_period]} text="Period" />
            <BackpexForm.input
              type="select"
              field={cf[:custom_period]}
              options={[{"Day", :day}, {"Week", :week}, {"Month", :month}, {"Year", :year}]}
              prompt="Select period"
            />
          </div>
          <div>
            <Layout.input_label for={cf[:end_date]} text="Contract end date" />
            <BackpexForm.input type="datetime-local" field={cf[:end_date]} />
          </div>
        </div>
      </.inputs_for>
    </div>
    """
  end
end
