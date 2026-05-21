defmodule WraftDocWeb.AdminNext.EnterprisePlanLive do
  @moduledoc """
  Backpex admin for custom (`custom IS NOT NULL`) `WraftDoc.Enterprise.Plan` rows
  — the "Enterprise" variant managed separately from the regular Plan admin.

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

  alias WraftDoc.Enterprise.Plan

  @impl Backpex.LiveResource
  def singular_name, do: "Enterprise Plan"

  @impl Backpex.LiveResource
  def plural_name, do: "Enterprise Plans"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      description: %{module: Backpex.Fields.Textarea, label: "Description"},
      plan_amount: %{module: Backpex.Fields.Text, label: "Amount"},
      currency: %{module: Backpex.Fields.Text, label: "Currency"},
      organisation: %{
        module: Backpex.Fields.BelongsTo,
        label: "Organisation",
        display_field: :name,
        live_resource: WraftDocWeb.AdminNext.OrganisationLive
      },
      payment_link: %{
        module: Backpex.Fields.Text,
        label: "Pay link",
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
      custom: %{
        module: Backpex.Fields.Text,
        label: "Custom",
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
    Plan.custom_plan_changeset(plan, attrs)
  end
end
