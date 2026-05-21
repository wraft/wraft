defmodule WraftDocWeb.AdminNext.PlanLive do
  @moduledoc """
  Backpex admin for non-custom (`custom IS NULL`) `WraftDoc.Enterprise.Plan` rows.

  Mirrors `WraftDocWeb.PlanAdmin` (Kaffy). Limitations vs. the original:
  - **Plan create does not call PaddleAPI.** The original `insert/2` wrapped
    `Enterprise.create_plan/1` which builds a `Multi` that talks to Paddle for
    product/price IDs. From this admin we save the row via `Plan.plan_changeset/2`
    only. If you need a Paddle-synced plan, use the existing seed flow or call
    `Enterprise.create_plan/1` directly from a script.
  - Embeds (`trial_period`, `limits`, `custom`) and the `features` array are
    read-only in this UI. Edit those via API/seeds.
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

  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  @impl Backpex.LiveResource
  def singular_name, do: "Plan"

  @impl Backpex.LiveResource
  def plural_name, do: "Plans"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      description: %{module: Backpex.Fields.Textarea, label: "Description"},
      plan_amount: %{module: Backpex.Fields.Text, label: "Amount"},
      currency: %{module: Backpex.Fields.Text, label: "Currency"},
      billing_interval: %{
        module: Backpex.Fields.Select,
        label: "Billing interval",
        options: [{"Monthly", :month}, {"Yearly", :year}]
      },
      type: %{
        module: Backpex.Fields.Select,
        label: "Type",
        options: [{"Free", :free}, {"Regular", :regular}, {"Enterprise", :enterprise}]
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
      features: %{
        module: Backpex.Fields.Text,
        label: "Features",
        except: [:new, :edit],
        render: fn assigns ->
          ~H'<span>{(@value || []) |> Enum.join(", ")}</span>'
        end
      },
      trial_period: %{
        module: Backpex.Fields.Text,
        label: "Trial period",
        except: [:new, :edit],
        render: fn assigns ->
          ~H'<span class="font-mono text-xs">{WraftDocWeb.AdminNext.PlanLive.embed_label(@value)}</span>'
        end
      },
      limits: %{
        module: Backpex.Fields.Text,
        label: "Limits",
        except: [:new, :edit],
        render: fn assigns ->
          ~H'<span class="font-mono text-xs">{WraftDocWeb.AdminNext.PlanLive.embed_label(@value)}</span>'
        end
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
    Plan.plan_changeset(plan, attrs)
  end

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
