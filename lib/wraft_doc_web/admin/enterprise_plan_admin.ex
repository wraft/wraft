defmodule WraftDocWeb.EnterprisePlanAdmin do
  @moduledoc """
  Admin panel for custom enterprise plan.
  """

  import Ecto.Query
  use Ecto.Schema

  alias WraftDoc.Billing.PaddleApi
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  def plural_name(_), do: "Enterprise Plans"

  def singular_name(_), do: "Enterprise Plan"

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      custom: %{
        name: "amount",
        value: fn x -> if x.custom != nil, do: x.custom.custom_amount end
      },
      custom_period: %{
        name: "duration",
        value: fn x ->
          if x.custom != nil,
            do: "#{x.custom.custom_period_frequency} x #{x.custom.custom_period}"
        end
      },
      link_validity: %{
        name: "link validity",
        value: fn x -> if x.custom != nil, do: x.custom.end_date end
      }
    ]
  end

  def resource_actions(_conn) do
    [
      paylink: %{
        name: "Copy pay link",
        # inputs: [
        #   org_select: %{
        #     name: "organisation_id",
        #     title: "Select Organisation",
        #     type: :select,
        #     options: get_organisations()
        #   }
        # ],
        action: fn _conn, plan ->
          plan
          |> PaddleApi.create_checkout_url()
          |> case do
            {:ok, url} ->
              copy_to_clipboard(url)
              {:ok, plan}

            {:error, error} ->
              {:error, plan, "Failed to create pay link: #{error}"}
          end
        end
      }
    ]
  end

  def copy_to_clipboard(url) do
    case :os.type() do
      {:unix, :darwin} ->
        System.cmd("sh", ["-c", "echo '#{url}' | pbcopy"])

      {:unix, _} ->
        System.cmd("sh", ["-c", "echo '#{url}' | xclip -selection clipboard"])

      {:win32, _} ->
        System.cmd("cmd", ["/c", "echo #{url} | clip"])
    end
  end

  def form_fields(_) do
    [
      name: %{
        label: "Name",
        required: true
      },
      description: %{label: "Description", required: true, type: :textarea},
      limits: %{
        label: "Limits",
        help_text: "Define usage limits for this plan."
      },
      organisation_id: %{
        label: "Organisations",
        type: :choices,
        choices: get_organisations(),
        required: true,
        help_text: "Select organisation to which this plan will be applied."
      },
      custom: %{
        label: "Custom",
        help_text: """
          Define custom pricing for this plan.
          Frequency of custom period. For example, if you select 'month' as the custom period and set the frequency to 3, the plan will be billed every 3 months.
        """
      }
    ]
  end

  def ordering(_) do
    [desc: :inserted_at]
  end

  defp get_organisations do
    Organisation
    |> where([o], o.name != "Personal")
    |> order_by(asc: :name)
    |> Repo.all()
    |> Enum.map(&{&1.name, &1.id})
  end

  # defp get_plans do
  #   Plan
  #   |> where([p], not is_nil(p.custom))
  #   |> order_by(asc: :name)
  #   |> Repo.all()
  #   |> Enum.map(&{"#{&1.name} - #{&1.description}", &1.id})
  # end

  # list resource will be used in future
  # def list_actions(_conn) do
  #   [
  #     generate_bulk_paylinks: %{
  #       name: "Generate Payment Links",
  #       prompt: true,
  #       modal_message: "Select plan and organization to generate payment link",
  #       inputs: [
  #         %{name: "plan", title: "Select Plan", use_select: true, options: get_plans()},
  #         %{name: "organisation_id", title: "Select organisation", use_select: true, options: get_organisations()},
  #       ],
  #       action: fn _conn, _plan, params ->
  #
  #         # plan
  #         # |> PaddleApi.create_checkout_url()
  #         # |> case do
  #         #   {:ok, url} ->
  #         #     copy_to_clipboard(url)
  #         #     :ok

  #         #   {:error, _error} ->
  #         #     {:error, "Failed to create pay link"}
  #         # end
  #         :ok
  #       end
  #     }
  #   ]
  # end

  # defp get_organisations do
  #   Organisation
  #   |> where([o], o.name != "Personal")
  #   |> order_by(asc: :name)
  #   |> WraftDoc.Repo.all()
  #   |> Enum.map(&[&1.name, &1.id])
  # end

  # defp get_plans do
  #   Plan
  #   |> where([p], not is_nil(p.custom))
  #   |> order_by(asc: :name)
  #   |> WraftDoc.Repo.all()
  #   |> Enum.map(&["#{&1.name} - #{&1.description}", &1])
  # end

  def custom_index_query(_conn, _schema, _query) do
    from(p in Plan,
      where: not is_nil(p.custom),
      where: not p.transaction_completed
    )
  end

  def create_changeset(schema, attrs) do
    Plan.custom_plan_changeset(schema, attrs)
  end

  def update_changeset(schema, attrs) do
    Plan.custom_plan_changeset(schema, attrs)
  end

  def insert(conn, changeset) do
    params = conn.params["plan"]

    conn.assigns[:admin_session]
    |> Enterprise.create_plan(params)
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end

  def update(conn, changeset) do
    params = conn.params["plan"]
    plan = changeset.data

    conn.assigns[:admin_session]
    |> Enterprise.update_plan(plan, params)
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end

  def delete(_conn, changeset) do
    changeset.data
    |> Enterprise.delete_plan()
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end
end
