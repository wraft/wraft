defmodule WraftDoc.Billing do
  @moduledoc """
  The billing module for wraft subscription management.
  """
  import Ecto.Query

  alias __MODULE__.PaddleApi
  alias __MODULE__.Subscription
  alias WraftDoc.Repo

  @doc """
  Gets active subscription of a user.
  """
  @spec active_subscription_for(Ecto.UUID.t()) :: {:ok, Subscription.t()} | {:error, atom()}
  def active_subscription_for(user_id) do
    user_id
    |> active_subscription_query()
    |> Repo.one()
    |> case do
      %Subscription{} = subscription ->
        {:ok, subscription}

      _ ->
        {:error, :no_active_subscription}
    end
  end

  @doc """
  Returns true  user has active subscription.
  """
  @spec has_active_subscription?(Ecto.UUID.t()) :: boolean()
  def has_active_subscription?(user_id) do
    user_id |> active_subscription_query() |> Repo.exists?()
  end

  defp active_subscription_query(user_id) do
    from(s in Subscription,
      where: s.user_id == ^user_id and s.status == ^"active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end

  @doc """
  Create subscription.
  """
  @spec subscription_created(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_created(params) do
    params = format_subscription_params(params)

    Repo.transaction(fn ->
      handle_subscription_created(params)
    end)
  end

  @doc """
  Update subscription.
  """
  @spec subscription_updated(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_updated(params) do
    Repo.transaction(fn ->
      handle_subscription_updated(params)
    end)
  end

  @doc """
  Cancel subscription.
  """
  @spec subscription_cancelled(map()) :: {:ok, Subscription.t()} | {:error, any()}
  def subscription_cancelled(params) do
    Repo.transaction(fn ->
      handle_subscription_cancelled(params)
    end)
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
        %Subscription{provider_subscription_id: provider_subscription_id} = subscription,
        paddle_price_id
      ) do
    provider_subscription_id
    |> PaddleApi.update_subscription(paddle_price_id)
    |> case do
      {:ok, response} ->
        subscription
        |> Subscription.changeset(%{
          provider_plan_id: Enum.at(response["items"], 0)["price"]["id"],
          next_bill_amount: Enum.at(response["items"], 0)["price"]["unit_price"]["amount"],
          next_payment_date: response["next_billed_at"],
          current_period_start: response["current_billing_period"]["starts_at"],
          current_period_end: response["current_billing_period"]["ends_at"]
        })
        |> Repo.update()

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets preview of a plan changes.
  """
  @spec change_plan_preview(Subscription.t(), binary()) :: {:ok, map()} | {:error, any()}
  def change_plan_preview(subscription, paddle_price_id) do
    case PaddleApi.update_subscription_preview(
           subscription.provider_subscription_id,
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
  def cancel_subscription(subscription) do
    case PaddleApi.cancel_subscription(subscription.provider_subscription_id) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_subscription_created(params) do
    %Subscription{}
    |> Subscription.changeset(params)
    |> Repo.insert()
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

    if subscription && not irrelevant? do
      params = format_subscription_params(params)

      subscription
      |> Subscription.changeset(params)
      |> Repo.update()
    end
  end

  defp handle_subscription_cancelled(params) do
    subscription =
      Subscription
      |> Repo.get_by(provider_subscription_id: params["id"])
      |> Repo.preload(:user)

    if subscription do
      changeset =
        Subscription.cancel_changeset(subscription, %{
          status: "canceled",
          canceled_at: params["canceled_at"]
        })

      Repo.update(changeset)
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
end
