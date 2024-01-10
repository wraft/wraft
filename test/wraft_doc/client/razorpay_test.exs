defmodule WraftDoc.Client.RazorpayTest do
  @moduledoc false
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Tesla.Mock

  alias WraftDoc.Client.Razorpay

  setup do
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: :warn) end)
  end

  describe "get_payment/1" do
    test "retrieves payment details successfully" do
      mock(fn
        %{method: :get} ->
          %Tesla.Env{
            status: 200,
            body: "payment details"
          }
      end)

      assert capture_log(fn -> Razorpay.get_payment("payment_id") end) =~
               "Payment details succcessfully retrieved"

      assert {:ok, "payment details"} == Razorpay.get_payment("payment_id")
    end

    test "returns an error when unable to retrieve payment details" do
      mock(fn
        %{method: :get} ->
          %Tesla.Env{
            status: 400,
            body: %{"error" => "error details"}
          }
      end)

      assert capture_log(fn -> Razorpay.get_payment("payment_id") end) =~
               "Unable to retrieve payment details"

      assert {:error, "error details"} == Razorpay.get_payment("non_existing_payment_id")
    end
  end
end
