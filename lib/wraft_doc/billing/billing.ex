defmodule WraftDoc.Billing do
  @moduledoc """
  The billing module for wraft subscription management.
  """
  import Ecto.Query
  alias Ecto.Multi

  alias __MODULE__.PaddleApi
  alias __MODULE__.Subscription
  alias __MODULE__.SubscriptionHistory
  alias __MODULE__.Transaction
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  @doc """
  Get a subscription from its UUID.
  """
  @spec get_subscription(Ecto.UUID.t()) :: Subscription.t() | nil
  def get_subscription(<<_::288>> = subscription_id) do
    case Repo.get(Subscription, subscription_id) do
      %Subscription{} = subscription -> subscription
      _ -> {:error, :invalid_id, "Subscription"}
    end
  end

  def get_subscription(_), do: {:error, :invalid_id, "Subscription"}

  @doc """
  Gets active subscription of a user.
  """
  @spec active_subscription_for(Ecto.UUID.t()) :: {:ok, Subscription.t()} | {:error, atom()}
  def active_subscription_for(<<_::288>> = organisation_id) do
    organisation_id
    |> active_subscription_query()
    |> Repo.one()
    |> Repo.preload([:user, :organisation, :plan])
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
  Create subscription.
  """
  @spec subscription_created(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_created(params) do
    params =
      params
      |> format_subscription_params()
      |> update_plan_status()

    case Repo.get_by(Subscription, organisation_id: params.organisation_id) do
      %Subscription{type: :free} = existing_subscription ->
        Multi.new()
        |> Multi.delete(:delete_existing, existing_subscription)
        |> Multi.insert(:new_subscription, Subscription.changeset(%Subscription{}, params))
        |> Repo.transaction()

      nil ->
        %Subscription{}
        |> Subscription.changeset(params)
        |> Repo.insert()
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
  @spec subscription_updated(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_updated(params) do
    handle_subscription_updated(params)
  end

  @doc """
  Cancel subscription.
  """
  @spec subscription_cancelled(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_cancelled(params) do
    subscription =
      Subscription
      |> Repo.get_by(provider_subscription_id: params["id"])
      |> Repo.preload(:user)

    Multi.new()
    |> Multi.insert(
      :create_history,
      SubscriptionHistory.changeset(%SubscriptionHistory{}, %{
        provider_subscription_id: subscription.provider_subscription_id,
        event_type: "cancelled",
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        transaction_id: subscription.transaction_id,
        user_id: subscription.user_id,
        organisation_id: subscription.organisation_id,
        plan_id: subscription.plan_id,
        metadata: subscription
      })
    )
    |> Multi.delete(:delete_subscription, subscription)
    |> Multi.run(
      :create_free_plan,
      fn _repo, _changes ->
        Enterprise.create_free_subscription(params["organisation_id"])
      end
    )
    |> Repo.transaction()
  end

  # may use later
  # @doc """
  # Update subscription when payment succeeded.
  # """
  # @spec subscription_payment_succeeded(map()) :: {:ok, Subscription.t()} | {:error, any()}
  # def subscription_payment_succeeded(params) do
  #   Repo.transaction(fn ->
  #     handle_subscription_payment_succeeded(params)
  #   end)
  # end

  @doc """
  Update subscription when plan changed.
  """
  @spec change_plan(Subscription.t(), binary()) :: {:ok, Subscription.t()} | {:error, any()}
  def change_plan(
        %Subscription{provider_plan_id: provider_plan_id},
        paddle_price_id
      )
      when paddle_price_id == provider_plan_id,
      do: {:error, "Already have same plan."}

  def change_plan(
        %Subscription{
          provider_subscription_id: provider_subscription_id
        },
        paddle_price_id
      ) do
    provider_subscription_id
    |> PaddleApi.update_subscription(paddle_price_id)
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
  @spec change_plan_preview(Subscription.t(), binary()) :: {:ok, map()} | {:error, any()}
  def change_plan_preview(%Subscription{provider_plan_id: provider_plan_id}, paddle_price_id)
      when paddle_price_id == provider_plan_id,
      do: {:error, "Already have same plan."}

  def change_plan_preview(
        %Subscription{provider_subscription_id: provider_subscription_id},
        paddle_price_id
      ) do
    case PaddleApi.update_subscription_preview(
           provider_subscription_id,
           paddle_price_id
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Cancel subscription.
  """
  @spec cancel_subscription(Subscription.t()) :: {:ok, Subscription.t()} | {:error, any()}

  def cancel_subscription(%Subscription{type: :free}),
    do: {:error, "Free subscription cannot be cancelled"}

  def cancel_subscription(subscription) do
    case PaddleApi.cancel_subscription(subscription.provider_subscription_id) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_subscription_params(params) do
    with {:ok, first_item} <- extract_first_item(params),
         {:ok, price} <- extract_price(first_item),
         {:ok, custom_data} <- extract_custom_data(params) do
      %{
        provider_subscription_id: params["id"],
        provider_plan_id: price["id"],
        provider: "paddle",
        status: params["status"],
        current_period_start: get_in(params, ["current_billing_period", "starts_at"]),
        current_period_end: get_in(params, ["current_billing_period", "ends_at"]),
        next_bill_amount: price["unit_price"]["amount"],
        next_payment_date: params["next_billed_at"],
        currency: params["currency_code"],
        transaction_id: params["transaction_id"],
        plan_id: custom_data["plan_id"],
        user_id: custom_data["user_id"],
        organisation_id: custom_data["organisation_id"]
      }
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp extract_first_item(params) do
    case params["items"] do
      [first_item | _] -> {:ok, first_item}
      _ -> {:error, :missing_items}
    end
  end

  defp extract_price(item) do
    case item["price"] do
      %{} = price -> {:ok, price}
      _ -> {:error, :missing_price}
    end
  end

  defp extract_custom_data(params) do
    case params["custom_data"] do
      %{} = custom_data -> {:ok, custom_data}
      _ -> {:error, :missing_custom_data}
    end
  end

  defp handle_subscription_updated(params) do
    subscription = Repo.get_by(Subscription, provider_subscription_id: params["id"])

    # In a situation where the subscription is paused and a payment succeeds, we
    # get notified of two "subscription_updated" webhook alerts from Paddle at the
    # same time.
    #
    #   * one with an `old_status` of "paused", and a `status` of "past_due"
    #   * the other with an `old_status` of "past_due", and a `status` of "active"
    #
    # https://developer.paddle.com/classic/guides/zg9joji1mzu0mduy-payment-failures
    #
    # Relying on the time when the webhooks are sent has caused issues where
    # subscriptions have ended up `past_due` after a successful payment. Therefore,
    # we're now explicitly ignoring the first webhook (with the update that's not
    # relevant to us).
    irrelevant? = params["old_status"] == "paused" && params["status"] == "past_due"

    # also move current subscription with transaction id, duration to history
    if subscription && not irrelevant? do
      params = format_subscription_params(params)

      Multi.new()
      |> Multi.insert(
        :create_history,
        SubscriptionHistory.changeset(%SubscriptionHistory{}, %{
          provider_subscription_id: subscription.provider_subscription_id,
          event_type: "plan updated",
          current_subscription_start: subscription.current_period_start,
          current_subscription_end: subscription.current_period_end,
          transaction_id: subscription.transaction_id,
          user_id: subscription.user_id,
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

  # may need in future
  # defp get_subscription(subscription_id) do
  #   Repo.get_by(Subscription, provider_subscription_id: subscription_id)
  # end

  # defp handle_subscription_payment_succeeded(params) do
  #   subscription =
  #   params["subscription_id"]
  #   |> get_subscription()
  #   |> if do

  #     subscription
  #     |> Subscription.changeset(%{
  #       next_bill_amount: params["next_payment"]["amount"],
  #       next_payment_date: params["next_payment"]["date"],
  #       current_period_start: params["last_payment"]["date"]
  #     })
  #     |> Repo.update()
  #     |> Repo.preload(:user)
  #   end
  # end

  @doc """
  Retrieves subscription history of an organisation.
  """
  @spec subscription_index(User.t(), map()) :: Scrivener.Page.t()
  def subscription_index(%{current_org_id: organisation_id}, params) do
    query =
      from(sh in SubscriptionHistory,
        where: sh.organisation_id == ^organisation_id,
        preload: [:user, :organisation, :plan]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Retrieves transactions of an organisation.
  """
  @spec get_transactions(Ecto.UUID.t(), map()) :: Scrivener.Page.t()
  def get_transactions(organisation_id, params) do
    query =
      from(t in Transaction,
        where: t.organisation_id == ^organisation_id,
        preload: [:organisation, :user, :plan]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Adds completed transaction to the database.
  """
  @spec transaction_completed(map()) :: {:ok, Transaction.t()} | {:error, any()}
  def transaction_completed(params) do
    params
    |> format_transaction_params()
    |> then(&Transaction.changeset(%Transaction{}, &1))
    |> Repo.insert()
    |> case do
      {:ok, transaction} ->
        # Subscription update webhook response doesn't contain transaction_id
        # so we need to update subscription with latest transaction_id
        Subscription
        |> where(provider_subscription_id: ^transaction.provider_subscription_id)
        |> Repo.update_all(set: [transaction_id: transaction.transaction_id])

        {:ok, transaction}

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_transaction_params(params) do
    %{
      transaction_id: params["id"],
      invoice_number: params["invoice_number"],
      invoice_id: params["invoice_id"],
      date: parse_datetime(params["billed_at"]),
      provider_subscription_id: params["subscription_id"],
      provider_plan_id: get_in(params, ["items", Access.at(0), "price", "id"]),
      billing_period_start: parse_datetime(params["billing_period"]["starts_at"]),
      billing_period_end: parse_datetime(params["billing_period"]["ends_at"]),
      subtotal_amount: params["details"]["totals"]["subtotal"],
      tax: params["details"]["totals"]["tax"],
      total_amount: params["details"]["totals"]["total"],
      currency: params["currency_code"],
      payment_method: get_payment_method(params),
      payment_method_details: get_payment_method_details(params),
      organisation_id: params["custom_data"]["organisation_id"],
      user_id: params["custom_data"]["user_id"],
      plan_id: params["custom_data"]["plan_id"]
    }
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
end
