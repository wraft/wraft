defmodule WraftDoc.Billing do
  @moduledoc """
  The billing module for wraft subscription management.
  """
  import Ecto.Query

  alias __MODULE__.Coupon
  alias __MODULE__.PaddleApi
  alias __MODULE__.Subscription
  alias __MODULE__.SubscriptionHistory
  alias __MODULE__.Transaction
  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  @doc """
  Get a subscription of a user's current organisation.
  """
  @spec get_subscription(%User{}) :: {:ok, Subscription.t()} | nil
  def get_subscription(%User{current_org_id: current_org_id}) do
    Subscription
    |> Repo.get_by(organisation_id: current_org_id)
    |> Repo.preload([:subscriber, :organisation, [plan: :coupon], :coupon])
    |> case do
      %Subscription{} = subscription -> {:ok, subscription}
      _ -> nil
    end
  end

  @doc """
  Get a subscription from its UUID.
  """
  @spec get_subscription_by_id(Ecto.UUID.t()) ::
          Subscription.t() | {:error, :invalid_id, String.t()}
  def get_subscription_by_id(<<_::288>> = subscription_id) do
    case Repo.get(Subscription, subscription_id) do
      %Subscription{} = subscription -> subscription
      _ -> {:error, :invalid_id, "Subscription"}
    end
  end

  def get_subscription_by_id(_), do: {:error, :invalid_id, "Subscription"}

  defp get_subscription_by_provider_subscription_id(provider_subscription_id) do
    Subscription
    |> Repo.get_by(provider_subscription_id: provider_subscription_id)
    |> Repo.preload([:subscriber, :organisation, [plan: :coupon], :coupon])
  end

  @doc """
  Get active subscription of a user's organisation.
  """
  @spec active_subscription_for(Ecto.UUID.t()) ::
          {:ok, Subscription.t()} | {:error, atom()}
  def active_subscription_for(<<_::288>> = organisation_id) do
    organisation_id
    |> active_subscription_query()
    |> Repo.one()
    |> Repo.preload([:subscriber, :organisation, [plan: :coupon], :coupon])
    |> case do
      %Subscription{} = subscription ->
        {:ok, subscription}

      _ ->
        {:error, :no_active_subscription}
    end
  end

  def active_subscription_for(_), do: {:error, :invalid_id, "Organisation"}

  @doc """
  Returns true  user has active subscription.
  """
  @spec has_active_subscription?(Ecto.UUID.t()) :: boolean()
  def has_active_subscription?(organisation_id) do
    organisation_id |> active_subscription_query() |> Repo.exists?()
  end

  defp active_subscription_query(organisation_id) do
    from(s in Subscription,
      where: s.organisation_id == ^organisation_id and s.status == ^"active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end

  @doc """
  Returns true user has a valid subscription.
  """
  @spec has_valid_subscription?(Ecto.UUID.t()) :: boolean()
  def has_valid_subscription?(organisation_id) do
    organisation_id |> valid_subscription_query() |> Repo.exists?()
  end

  defp valid_subscription_query(organisation_id) do
    from(s in Subscription,
      where: s.organisation_id == ^organisation_id,
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end

  @doc """
  Update subscription when plan changed.
  """
  @spec change_plan(Subscription.t(), User.t(), Plan.t()) :: {:ok, map()} | {:error, String.t()}

  def change_plan(
        %Subscription{plan: %{type: :free}},
        _,
        _
      ),
      do: {:error, "Can't change plan for free plan, create new subscription"}

  def change_plan(
        %Subscription{provider_plan_id: provider_plan_id},
        _,
        %{plan_id: plan_id}
      )
      when plan_id == provider_plan_id,
      do: {:error, "Already have same plan."}

  def change_plan(
        %Subscription{
          provider_subscription_id: provider_subscription_id
        },
        current_user,
        plan
      ) do
    provider_subscription_id
    |> PaddleApi.update_subscription(current_user, plan)
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets preview of a plan changes.
  """
  @spec change_plan_preview(Subscription.t(), Plan.t()) :: {:ok, map()} | {:error, String.t()}
  def change_plan_preview(%Subscription{plan: %{type: :free}}, _),
    do: {:error, "Change plan preview not available for free plan."}

  def change_plan_preview(%Subscription{provider_plan_id: provider_plan_id}, %{plan_id: plan_id})
      when provider_plan_id == plan_id,
      do: {:error, "Already have same plan."}

  def change_plan_preview(
        %Subscription{provider_subscription_id: provider_subscription_id},
        plan
      ) do
    provider_subscription_id
    |> PaddleApi.update_subscription_preview(plan)
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Cancel subscription.
  """
  @spec cancel_subscription(Subscription.t()) :: {:ok, map()} | {:error, String.t()}

  def cancel_subscription(%Subscription{plan: %{type: :free}}),
    do: {:error, "Free subscription cannot be cancelled"}

  def cancel_subscription(%Subscription{provider_subscription_id: provider_subscription_id}) do
    provider_subscription_id
    |> PaddleApi.cancel_subscription()
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Activate trailing subscription.
  """
  @spec activate_trial_subscription(Subscription.t()) ::
          {:ok, Subscription.t()} | {:error, String.t()}
  def activate_trial_subscription(%Subscription{
        status: "trialing",
        provider_subscription_id: provider_subscription_id
      }) do
    provider_subscription_id
    |> PaddleApi.activate_trailing_subscription()
    |> case do
      {:ok, response} ->
        params = format_subscription_params(response)

        provider_subscription_id
        |> get_subscription_by_provider_subscription_id()
        |> Subscription.update_changeset(params)
        |> Repo.update()

      {:error, error} ->
        {:error, error}
    end
  end

  def activate_trial_subscription(%Subscription{status: status}),
    do: {:error, "Current status: #{status}, Only trailing subscription need be activated"}

  @doc """
  Retrieves subscription history of an organisation.
  """
  @spec subscription_index(Ecto.UUID.t(), map()) :: Scrivener.Page.t() | nil
  def subscription_index(<<_::288>> = organisation_id, params) do
    query =
      from(sh in SubscriptionHistory,
        where: sh.organisation_id == ^organisation_id,
        preload: [:subscriber, :organisation, [plan: :coupon], :coupon]
      )

    Repo.paginate(query, params)
  end

  def subscription_index(_organisation_id, _params), do: nil

  @doc """
  Retrieves transactions of an organisation.
  """
  @spec get_transactions(Ecto.UUID.t(), map()) :: Scrivener.Page.t() | nil
  def get_transactions(<<_::288>> = organisation_id, params) do
    query =
      from(t in Transaction,
        where: t.organisation_id == ^organisation_id,
        preload: [:organisation, :subscriber, [plan: :coupon], :coupon]
      )

    Repo.paginate(query, params)
  end

  def get_transactions(_organisation_id, _params), do: nil

  @doc """
  Create subscription.
  """
  @spec on_create_subscription(map()) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def on_create_subscription(params) do
    params =
      params
      |> format_subscription_params()
      |> update_plan_status()

    Subscription
    |> Repo.get_by(organisation_id: params.organisation_id)
    |> Repo.preload(:plan)
    |> case do
      %Subscription{plan: %{type: :free}} = subscription ->
        Multi.new()
        |> Multi.delete(:delete_existing_subscription, subscription)
        |> Multi.insert(:new_subscription, Subscription.changeset(%Subscription{}, params))
        |> Repo.transaction()

      %Subscription{} = subscription ->
        Multi.new()
        |> Multi.insert(
          :create_history,
          SubscriptionHistory.changeset(%SubscriptionHistory{}, %{
            provider_subscription_id: subscription.provider_subscription_id,
            event_type: "plan updated",
            current_subscription_start: subscription.start_date,
            current_subscription_end: subscription.end_date,
            transaction_id: subscription.transaction_id,
            subscriber_id: subscription.subscriber_id,
            organisation_id: subscription.organisation_id,
            plan_id: subscription.plan_id
          })
        )
        |> Multi.delete(:delete_existing_subscription, subscription)
        |> Multi.insert(:new_subscription, Subscription.changeset(%Subscription{}, params))
        |> Repo.transaction()

      _ ->
        Multi.new()
        |> Multi.insert(:new_subscription, Subscription.changeset(%Subscription{}, params))
        |> Repo.transaction()
    end
    |> case do
      {:ok, %{new_subscription: subscription}} ->
        {:ok, subscription}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  defp update_plan_status(%{plan_id: plan_id} = params) do
    case Repo.get(Plan, plan_id) do
      %Plan{type: :regular} ->
        Map.put(params, :type, :regular)

      %Plan{type: :enterprise} = plan ->
        plan
        |> Plan.changeset(%{is_active?: false})
        |> Repo.update()

        Map.put(params, :type, :enterprise)

      _ ->
        params
    end
  end

  @doc """
  Update subscription.
  """
  @spec on_update_subscription(map()) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def on_update_subscription(%{"status" => status} = params) when status == "active" do
    params
    |> handle_on_update_subscription()
    |> case do
      {:ok, %{update_subscription: subscription}} ->
        {:ok, subscription}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  def on_update_subscription(%{"status" => status}), do: {:error, "Invalid status: #{status}"}

  @doc """
  Cancel subscription.
  """
  @spec on_cancel_subscription(map()) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def on_cancel_subscription(%{
        "id" => subscription_id,
        "custom_data" => %{"organisation_id" => organisation_id}
      }) do
    subscription =
      Subscription
      |> Repo.get_by(provider_subscription_id: subscription_id)
      |> Repo.preload(:subscriber)

    Multi.new()
    |> Multi.insert(
      :create_history,
      SubscriptionHistory.changeset(%SubscriptionHistory{}, %{
        provider_subscription_id: subscription.provider_subscription_id,
        event_type: "cancelled",
        current_subscription_start: subscription.start_date,
        current_subscription_end: subscription.end_date,
        transaction_id: subscription.transaction_id,
        subscriber_id: subscription.subscriber_id,
        organisation_id: subscription.organisation_id,
        plan_id: subscription.plan_id
      })
    )
    |> Multi.delete(:delete_subscription, subscription)
    |> Multi.run(
      :create_free_plan,
      fn _repo, _changes ->
        Enterprise.create_free_subscription(organisation_id)
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_subscription: subscription}} ->
        {:ok, subscription}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Adds completed transaction to the database.
  """
  @spec on_complete_transaction(map()) :: {:ok, Transaction.t()} | {:error, Ecto.Changeset.t()}
  def on_complete_transaction(params) do
    Multi.new()
    |> Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, format_transaction_params(params))
    )
    |> Multi.run(:update_subscription, fn _repo, %{transaction: transaction} ->
      update_subscription_transaction(transaction)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transaction: transaction}} ->
        update_coupon_usage(params)
        {:ok, transaction}

      {:error, _operation, error, _changes} ->
        {:error, error}
    end
  end

  defp update_subscription_transaction(%{provider_subscription_id: sub_id, transaction_id: txn_id}) do
    Subscription
    |> where(provider_subscription_id: ^sub_id)
    |> Repo.update_all(set: [transaction_id: txn_id])
    |> then(&{:ok, &1})
  end

  defp update_coupon_usage(%{"discount_id" => nil}), do: nil

  defp update_coupon_usage(%{"discount_id" => coupon_id}) do
    Coupon
    |> where(coupon_id: ^coupon_id)
    |> select([c], {c.times_used + 1, c.usage_limit})
    |> Repo.one()
    |> case do
      {new_usage, limit} when new_usage >= limit ->
        Coupon
        |> where(coupon_id: ^coupon_id)
        |> Repo.update_all(set: [status: "expired"], inc: [times_used: 1])
        |> then(&{:ok, &1})

      _ ->
        Coupon
        |> where(coupon_id: ^coupon_id)
        |> Repo.update_all(inc: [times_used: 1])
        |> then(&{:ok, &1})
    end
  end

  defp handle_on_update_subscription(%{"id" => provider_subscription_id} = params) do
    subscription = Repo.get_by(Subscription, provider_subscription_id: provider_subscription_id)
    irrelevant? = params["old_status"] == "paused" && params["status"] == "past_due"

    if subscription && not irrelevant? do
      params = format_subscription_params(params)

      Multi.new()
      |> Multi.insert(
        :create_history,
        SubscriptionHistory.changeset(%SubscriptionHistory{}, %{
          provider_subscription_id: subscription.provider_subscription_id,
          event_type: "plan updated",
          current_subscription_start: subscription.start_date,
          current_subscription_end: subscription.end_date,
          transaction_id: subscription.transaction_id,
          subscriber_id: subscription.subscriber_id,
          organisation_id: subscription.organisation_id,
          plan_id: subscription.plan_id
        })
      )
      |> Multi.update(
        :update_subscription,
        Subscription.update_changeset(subscription, params)
      )
      |> Repo.transaction()
    end
  end

  defp format_subscription_params(
         %{
           "id" => provider_subscription_id,
           "items" => [
             %{
               "price" => %{
                 "id" => provider_plan_id,
                 "unit_price" => %{"amount" => next_bill_amount}
               }
             }
             | _
           ],
           "status" => status,
           "current_billing_period" => %{"starts_at" => start_date, "ends_at" => end_date},
           "next_billed_at" => next_bill_date,
           "currency_code" => currency,
           "discount" => discount,
           "custom_data" => %{
             "plan_id" => plan_id,
             "user_id" => subscriber_id,
             "organisation_id" => organisation_id
           }
         } = params
       ) do
    %{
      provider_subscription_id: provider_subscription_id,
      provider_plan_id: provider_plan_id,
      status: status,
      start_date: start_date,
      end_date: end_date,
      next_bill_amount: next_bill_amount,
      next_bill_date: next_bill_date,
      currency: currency,
      coupon_id: get_coupon_id(discount["id"]),
      coupon_start_date: discount["starts_at"],
      coupon_end_date: discount["ends_at"],
      transaction_id: Map.get(params, "transaction_id", nil),
      plan_id: plan_id,
      subscriber_id: subscriber_id,
      organisation_id: organisation_id
    }
  end

  defp format_transaction_params(
         %{
           "id" => transaction_id,
           "invoice_number" => invoice_number,
           "invoice_id" => invoice_id,
           "billed_at" => billed_at,
           "subscription_id" => subscription_id,
           "discount_id" => discount_id,
           "items" => [%{"price" => %{"id" => provider_plan_id}} | _],
           "billing_period" => %{
             "starts_at" => period_starts_at,
             "ends_at" => period_ends_at
           },
           "details" => %{
             "totals" => %{
               "subtotal" => subtotal,
               "tax" => tax,
               "discount" => discount,
               "total" => total
             }
           },
           "currency_code" => currency,
           "custom_data" => %{
             "organisation_id" => org_id,
             "user_id" => user_id,
             "plan_id" => plan_id
           }
         } = params
       ) do
    %{
      transaction_id: transaction_id,
      invoice_number: invoice_number,
      invoice_id: invoice_id,
      date: parse_datetime(billed_at),
      provider_subscription_id: subscription_id,
      provider_plan_id: provider_plan_id,
      billing_period_start: parse_datetime(period_starts_at),
      billing_period_end: parse_datetime(period_ends_at),
      subtotal_amount: subtotal,
      tax: tax,
      discount_amount: discount,
      total_amount: total,
      currency: currency,
      payment_method: get_payment_method(params),
      payment_method_details: get_payment_method_details(params),
      coupon_id: get_coupon_id(discount_id),
      organisation_id: org_id,
      subscriber_id: user_id,
      plan_id: plan_id
    }
  end

  defp get_coupon_id(nil), do: nil

  defp get_coupon_id(discount_id) do
    Coupon
    |> where([c], c.coupon_id == ^discount_id)
    |> select([c], c.id)
    |> Repo.one()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime) do
    datetime
    |> NaiveDateTime.from_iso8601!()
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp get_payment_method(params) do
    params["payments"]
    |> Enum.find(fn payment -> payment["status"] == "captured" end)
    |> then(fn payment -> payment && payment["method_details"]["type"] end)
  end

  defp get_payment_method_details(params) do
    params["payments"]
    |> Enum.find(fn payment -> payment["status"] == "captured" end)
    |> then(fn payment -> payment && payment["method_details"] end)
  end

  @doc """
  Creates a coupon.
  """
  @spec create_coupon(map()) ::
          {:ok, Coupon.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def create_coupon(params) do
    Multi.new()
    |> Multi.insert(:coupon, fn _ ->
      Coupon.changeset(%Coupon{}, params)
    end)
    |> Multi.run(:provider_coupon, fn _, %{} ->
      PaddleApi.create_coupon(params)
    end)
    |> Multi.update(:update_coupon, fn %{
                                         coupon: coupon,
                                         provider_coupon: %{
                                           "id" => coupon_id,
                                           "status" => status,
                                           "code" => coupon_code,
                                           "usage_limit" => usage_limit
                                         }
                                       } ->
      Coupon.changeset(coupon, %{
        coupon_id: coupon_id,
        status: status,
        coupon_code: coupon_code,
        usage_limit: usage_limit,
        start_date: DateTime.utc_now()
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_coupon: coupon}} ->
        {:ok, coupon}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Update coupon.
  """
  @spec update_coupon(Coupon.t(), map()) ::
          {:ok, Coupon.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def update_coupon(%{coupon_id: coupon_id} = coupon, params) do
    Multi.new()
    |> Multi.run(:provider_coupon, fn _, _ ->
      PaddleApi.update_coupon(coupon_id, params)
    end)
    |> Multi.update(:update_coupon, fn %{
                                         provider_coupon: %{
                                           "id" => coupon_id,
                                           "status" => status,
                                           "code" => coupon_code,
                                           "usage_limit" => usage_limit
                                         }
                                       } ->
      Coupon.changeset(
        coupon,
        Map.merge(params, %{
          coupon_id: coupon_id,
          status: status,
          coupon_code: coupon_code,
          usage_limit: usage_limit
        })
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_coupon: coupon}} ->
        {:ok, coupon}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Archives coupon in provider.
  """
  @spec delete_coupon(Coupon.t()) ::
          {:ok, Coupon.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def delete_coupon(%{coupon_id: coupon_id} = coupon) do
    Multi.new()
    |> Multi.run(:provider_coupon, fn _, _ ->
      PaddleApi.delete_coupon(coupon_id)
    end)
    |> Multi.update(:archive_coupon, fn _ ->
      Coupon.changeset(coupon, %{status: "archived"})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{archive_coupon: coupon}} ->
        {:ok, coupon}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  @doc """
  Handles response for admin modules.
  """
  @spec handle_response(map(), Ecto.Changeset.t()) ::
          {:ok, map()} | {:error, Ecto.Changeset.t()} | {:error, {Ecto.Changeset.t(), String.t()}}
  def handle_response(response, changeset) do
    case response do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end
end
