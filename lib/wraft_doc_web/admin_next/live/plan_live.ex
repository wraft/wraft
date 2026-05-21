defmodule WraftDocWeb.AdminNext.PlanLive do
  @moduledoc """
  Backpex admin for non-custom (`custom IS NULL`) `WraftDoc.Enterprise.Plan` rows.

  Form is organised into three panels — **Basics**, **Features**, and
  **Limits & entitlements** — mirroring the product mockup.

  Mirrors `WraftDocWeb.PlanAdmin` (Kaffy). Limitations vs. the original:
  - **Plan create does not call PaddleAPI.** The original `insert/2` wrapped
    `Enterprise.create_plan/1` which builds a `Multi` that talks to Paddle for
    product/price IDs. From this admin we save the row via `Plan.plan_changeset/2`
    only. If you need a Paddle-synced plan, use the existing seed flow or call
    `Enterprise.create_plan/1` directly from a script.
  - Soft delete: the row's `is_active?` is set to `false` instead of a hard delete.
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
    subtitle: "Standard subscription plans billed via Paddle."

  import Ecto.Query

  alias Backpex.HTML.Form, as: BackpexForm
  alias Backpex.HTML.Layout
  alias WraftDoc.Enterprise.Plan

  @impl Backpex.LiveResource
  def singular_name, do: "Plan"

  @impl Backpex.LiveResource
  def plural_name, do: "Plans"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def panels do
    # `features_panel` has its label suppressed (nil) because the features field
    # renders its own section header with the "+ Add feature" button.
    [
      features_panel: nil,
      limits_panel: "Limits & entitlements"
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      # ── Basics ───────────────────────────────────────────────────────
      name: %{
        module: Backpex.Fields.Text,
        label: "Plan name",
        placeholder: "e.g. Growth",
        searchable: true,
        orderable: true
      },
      description: %{
        module: Backpex.Fields.Textarea,
        label: "Tagline",
        placeholder: "One sentence describing this tier",
        help_text: "Shown on the pricing page below the plan name.",
        rows: 2
      },
      plan_amount: %{
        module: Backpex.Fields.Text,
        label: "Price (USD)",
        placeholder: "49"
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
        render_form: &__MODULE__.render_trial_length_form/1
      },
      is_active?: %{
        module: Backpex.Fields.Boolean,
        label: "Show on pricing page",
        help_text: "Public visibility",
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            @value && "bg-success/10 text-success",
            !@value && "bg-error/10 text-error"
          ]}>
            {if @value, do: "Visible", else: "Hidden"}
          </span>
          """
        end
      },
      type: %{
        module: Backpex.Fields.Select,
        label: "Type",
        options: [{"Free", :free}, {"Regular", :regular}, {"Enterprise", :enterprise}],
        except: [:new, :edit]
      },
      currency: %{
        module: Backpex.Fields.Text,
        label: "Currency",
        except: [:new, :edit]
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
        render_form: &__MODULE__.render_features_form/1
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
        render_form: &__MODULE__.render_limits_form/1
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
    Keyword.delete(default_actions, :delete) ++ [delete: %{module: __MODULE__.SoftDeactivate}]
  end

  def item_query(query, _live_action, _assigns) do
    from(p in query,
      where: is_nil(p.custom),
      where: p.is_active? == true,
      preload: [:coupon, :creator]
    )
  end

  def changeset(plan, attrs, _metadata) do
    Plan.plan_changeset(plan, attrs |> normalize_features() |> normalize_trial_period())
  end

  # The features field submits as `change[features][]`, which Phoenix parses as
  # a list. Strip whitespace and drop empty rows (the UI keeps blank rows for
  # editing affordance, but we don't want them persisted).
  defp normalize_features(%{"features" => features} = attrs) when is_list(features) do
    list = features |> Enum.map(&String.trim(to_string(&1))) |> Enum.reject(&(&1 == ""))
    Map.put(attrs, "features", list)
  end

  defp normalize_features(attrs), do: attrs

  # The trial-length input always submits a hidden `period=day`, so a blank
  # frequency would otherwise persist as `%TrialPeriod{period: :day, frequency: nil}`
  # — semantically "no trial" but with a stray period set. Drop the whole embed
  # from params when frequency is empty so `cast_embed` leaves `trial_period: nil`.
  defp normalize_trial_period(%{"trial_period" => %{"frequency" => freq} = tp} = attrs) do
    if String.trim(to_string(freq)) == "" do
      Map.delete(attrs, "trial_period")
    else
      # Keep only the fields the embed cares about (drop Phoenix's _persistent_id etc.).
      Map.put(attrs, "trial_period", Map.take(tp, ["frequency", "period"]))
    end
  end

  defp normalize_trial_period(attrs), do: attrs

  @doc """
  Formats an Ecto embed (struct or nil) as a compact, JSON-encoded map.
  Used by `:render` fns for trial_period/limits/custom — those structs don't
  derive Jason.Encoder, so plain `Jason.encode!/1` blows up.
  """
  def embed_label(nil), do: "—"

  def embed_label(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
    |> Jason.encode!()
  end

  def embed_label(value), do: inspect(value)

  @doc "Human label for a `TrialPeriod` embed (e.g. `14 days`)."
  def trial_period_label(nil), do: "—"

  def trial_period_label(%{frequency: freq, period: period}) when not is_nil(freq) do
    unit = period |> to_string() |> pluralize(freq)
    "#{freq} #{unit}"
  end

  def trial_period_label(_), do: "—"

  defp pluralize("", _n), do: "days"
  defp pluralize(unit, 1), do: unit
  defp pluralize(unit, _n), do: unit <> "s"

  # ─── Custom form renderers ──────────────────────────────────────────────

  @doc false
  # Trial length: a single number input (days). The embed's `:period` is
  # always submitted as `"day"` so cast_embed builds a valid TrialPeriod.
  def render_trial_length_form(assigns) do
    ~H"""
    <div>
      <Layout.field_container>
        <:label align={:top}>
          <Layout.input_label text={@field_options[:label]} />
        </:label>
        <.inputs_for :let={tp} field={@form[@name]}>
          <div class="flex items-center gap-2">
            <BackpexForm.input
              type="number"
              field={tp[:frequency]}
              placeholder="14"
              class="max-w-[8rem]"
              min="0"
            />
            <span class="text-base-content/60 text-sm">days</span>
            <input type="hidden" name={tp[:period].name} value="day" />
          </div>
        </.inputs_for>
      </Layout.field_container>
    </div>
    """
  end

  @doc false
  # Renders the "Features" panel content: a header (title + subtitle + "+ Add
  # feature" button) and a list of feature rows. Each row has a check icon, a
  # text input named `change[features][]`, and a remove button. A `FeaturesList`
  # JS hook (assets/js/admin.js) clones a `<template>` row for add and removes
  # rows on click. `phx-update="ignore"` keeps the JS-managed DOM intact across
  # LiveView re-renders.
  def render_features_form(assigns) do
    features =
      case assigns.form[assigns.name].value do
        list when is_list(list) -> list
        _ -> []
      end

    # On `:new` only, show two empty rows as an editing affordance (mirrors the
    # mockup). On `:edit` of a plan that genuinely has no features, render none —
    # users can click "+ Add feature" if they want to add some.
    features =
      if features == [] and assigns.live_action == :new, do: ["", ""], else: features

    input_name = Phoenix.HTML.Form.input_name(assigns.form, assigns.name) <> "[]"

    assigns =
      assigns
      |> assign(:features, features)
      |> assign(:input_name, input_name)

    ~H"""
    <div
      id={Phoenix.HTML.Form.input_id(@form, @name) <> "_section"}
      phx-hook="FeaturesList"
      phx-update="ignore"
      data-input-name={@input_name}
    >
      <hr class="border-base-200 mb-6 border" />
      <div class="flex items-start justify-between gap-4 px-6">
        <div>
          <h3 class="text-base-content text-lg font-semibold">Features</h3>
          <p class="text-base-content/60 text-sm">Bullet points shown on the plan card.</p>
        </div>
        <button type="button" data-features-action="add" class="btn btn-sm btn-outline">
          <Backpex.HTML.CoreComponents.icon name="hero-plus" class="size-4" /> Add feature
        </button>
      </div>

      <hr class="border-base-200 mt-4 mb-2 border" />

      <template data-features-template>
        <.feature_row placeholder="Add a feature" />
      </template>

      <div data-features-rows>
        <.feature_row
          :for={{feat, i} <- Enum.with_index(@features)}
          name={@input_name}
          value={feat}
          placeholder={"Feature #{i + 1} — e.g. 10 seats"}
        />
      </div>
    </div>
    """
  end

  attr :name, :any, default: nil
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Add a feature"

  defp feature_row(assigns) do
    ~H"""
    <div class="features-row flex items-center gap-3 px-6 py-1">
      <Backpex.HTML.CoreComponents.icon
        name="hero-check"
        class="text-base-content/40 size-4 shrink-0"
      />
      <input type="text" name={@name} value={@value} class="input w-full" placeholder={@placeholder} />
      <button
        type="button"
        data-features-action="remove"
        class="text-base-content/50 hover:text-error shrink-0"
      >
        <Backpex.HTML.CoreComponents.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    """
  end

  @doc false
  # Limits embed: 4 numeric quota inputs. Schema fields → image labels:
  #   organisation_invite  → "Seats included"
  #   instance_create      → "Documents per month"
  #   content_type_create  → "Content types"
  #   organisation_create  → "Sub-organisations"
  def render_limits_form(assigns) do
    ~H"""
    <div class="px-6 py-2">
      <.inputs_for :let={lf} field={@form[@name]}>
        <div class="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
          <div>
            <Layout.input_label for={lf[:organisation_invite]} text="Seats included" />
            <BackpexForm.input type="number" field={lf[:organisation_invite]} min="0" />
          </div>
          <div>
            <Layout.input_label for={lf[:instance_create]} text="Documents per month" />
            <BackpexForm.input type="number" field={lf[:instance_create]} min="0" />
          </div>
          <div>
            <Layout.input_label for={lf[:content_type_create]} text="Content types" />
            <BackpexForm.input type="number" field={lf[:content_type_create]} min="0" />
          </div>
          <div>
            <Layout.input_label for={lf[:organisation_create]} text="Sub-organisations" />
            <BackpexForm.input type="number" field={lf[:organisation_create]} min="0" />
          </div>
        </div>
      </.inputs_for>
    </div>
    """
  end

  defmodule SoftDeactivate do
    @moduledoc "Marks the plan inactive instead of deleting (matches Kaffy)."
    use Backpex.ItemAction

    alias WraftDoc.Enterprise.Plan, as: PlanSchema
    alias WraftDoc.Repo
    require Logger

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H"""
      <Backpex.HTML.CoreComponents.icon
        name="hero-archive-box-x-mark"
        class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-red-600"
      />
      """
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Deactivate"

    @impl Backpex.ItemAction
    def confirm(_assigns), do: "Deactivate this plan (sets is_active? = false)?"

    @impl Backpex.ItemAction
    def confirm_label(_assigns), do: "Deactivate"

    @impl Backpex.ItemAction
    def cancel_label(_assigns), do: "Cancel"

    @impl Backpex.ItemAction
    def handle(socket, items, _data) do
      deactivated =
        Enum.flat_map(items, fn %PlanSchema{} = plan ->
          plan
          |> Ecto.Changeset.change(%{is_active?: false})
          |> Repo.update()
          |> case do
            {:ok, p} ->
              [p]

            {:error, reason} ->
              Logger.error("PlanLive deactivate failed for #{plan.id}: #{inspect(reason)}")
              []
          end
        end)

      Enum.each(deactivated, fn plan ->
        socket.assigns.live_resource.on_item_deleted(socket, plan)
      end)

      {:ok,
       socket
       |> Phoenix.LiveView.clear_flash()
       |> Phoenix.LiveView.put_flash(:info, "Deactivated #{length(deactivated)} plan(s).")}
    end
  end
end
