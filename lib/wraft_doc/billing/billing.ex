defmodule WraftDoc.Billing do
  @moduledoc """
  The billing module.
  """
  import Ecto.Query

  alias __MODULE__.PaddleApi
  alias __MODULE__.Subscription
  alias WraftDoc.Repo

  def active_subscription_for(user_id) do
    user_id |> active_subscription_query() |> Repo.one()
  end

  def has_active_subscription?(user_id) do
    user_id |> active_subscription_query() |> Repo.exists?()
  end

  defp active_subscription_query(user_id) do
    from(s in Subscription,
      # check and update status
      where: s.user_id == ^user_id and s.status == ^"active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
  end

  def subscription_created(params) do
    params = format_subscription_params(params)

    Repo.transaction(fn ->
      handle_subscription_created(params)
    end)
  end

  def subscription_updated(params) do
    Repo.transaction(fn ->
      handle_subscription_updated(params)
    end)
  end

  def subscription_cancelled(params) do
    Repo.transaction(fn ->
      handle_subscription_cancelled(params)
    end)
  end

  def subscription_payment_succeeded(params) do
    Repo.transaction(fn ->
      handle_subscription_payment_succeeded(params)
    end)
  end

  def change_plan(user, new_plan_id) do
    subscription = active_subscription_for(user.id)

    res =
      PaddleApi.update_subscription(subscription.provider_subscription_id, %{
        provider_plan_id: new_plan_id
      })

    case res do
      {:ok, response} ->
        amount = :erlang.float_to_binary(response["next_payment"]["amount"] / 1, decimals: 2)

        subscription
        |> Subscription.changeset(%{
          provider_plan_id: Integer.to_string(response["plan_id"]),
          next_bill_amount: amount,
          next_payment_date: response["next_payment"]["date"]
        })
        |> Repo.update()

      error ->
        error
    end
  end

  def change_plan_preview(subscription, new_plan_id) do
    case PaddleApi.update_subscription_preview(
           subscription.provider_subscription_id,
           new_plan_id
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel_subscription(subscription) do
    case PaddleApi.cancel_subscription(subscription.provider_subscription_id) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_subscription_created(params) do
    %Subscription{}
    |> Subscription.changeset(params)
    |> Repo.insert!()
  end

  defp handle_subscription_updated(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

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
      params =
        params
        |> format_params()
        |> format_subscription_params()

      subscription
      |> Subscription.changeset(params)
      |> Repo.update!()
    end
  end

  defp handle_subscription_cancelled(params) do
    subscription =
      Subscription
      |> Repo.get_by(provider_subscription_id: params["subscription_id"])
      |> Repo.preload(:user)

    if subscription do
      changeset =
        Subscription.changeset(subscription, %{
          status: params["status"]
        })

      Repo.update!(changeset)
      # implement mail if needed
      # subscription
      # |> Map.fetch!(:user)
      # |> WraftDoc.Email.cancellation_email()
      # |> WraftDoc.Mailer.send()
    end
  end

  def get_subscription(subscription_id) do
    Repo.get_by(Subscription, provider_subscription_id: subscription_id)
  end

  defp handle_subscription_payment_succeeded(params) do
    subscription = Repo.get_by(Subscription, provider_subscription_id: params["subscription_id"])

    if subscription do
      {:ok, api_subscription} = PaddleApi.get_subscription(subscription.paddle_subscription_id)

      amount =
        :erlang.float_to_binary(api_subscription["next_payment"]["amount"] / 1, decimals: 2)

      subscription
      |> Subscription.changeset(%{
        next_bill_amount: amount,
        next_payment_date: api_subscription["next_payment"]["date"],
        current_period_start: api_subscription["last_payment"]["date"]
      })
      |> Repo.update!()
      |> Repo.preload(:user)
    end
  end

  defp format_params(%{"passthrough" => passthrough} = params) do
    passthrough
    |> to_string()
    |> String.split(";")
    |> case do
      # [user_id] ->
      #   user = Repo.get!(User, user_id)

      ["user:" <> user_id, "organisation_id:" <> organisation_id] ->
        params
        |> Map.put("passthrough", user_id)
        |> Map.put("organisation_id", organisation_id)
    end
  end

  defp format_params(params) do
    params
  end

  def format_subscription_params(data) do
    %{
      "provider_subscription_id" => data["id"],
      "provider" => "paddle",
      "status" => data["state"],
      "current_period_start" => parse_unix_timestamp(data["beginInSeconds"]),
      "current_period_end" => parse_unix_timestamp(data["nextInSeconds"]),
      "canceled_at" => parse_unix_timestamp(data["canceledDateInSeconds"]),
      "next_payment_date" => parse_date_from_seconds(data["nextChargeDateInSeconds"]),
      "next_bill_amount" => to_string(data["nextChargeTotal"]),
      "plan_id" => data["passthrough"]["plan_id"],
      "user_id" => data["passthrough"]["user_id"],
      "currency" => data["currency"],
      "update_url" => data["update_url"],
      "cancel_url" => data["cancel_url"],
      # store entire map or select specific fields if needed
      "metadata" => data
    }
  end

  # may remove this function.
  defp parse_unix_timestamp(nil), do: nil

  defp parse_unix_timestamp(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp parse_date_from_seconds(nil), do: nil

  defp parse_date_from_seconds(seconds) do
    seconds
    |> DateTime.from_unix!()
    |> DateTime.to_date()
  end

  def pretty_join([str]), do: str

  def pretty_join(list) do
    [last_string | rest] = Enum.reverse(list)

    rest_string =
      rest
      |> Enum.reverse()
      |> Enum.join(", ")

    "#{rest_string} and #{last_string}"
  end

  def pretty_list(list) do
    list
    |> Enum.map(&String.replace("#{&1}", "_", " "))
    |> pretty_join()
  end
end
