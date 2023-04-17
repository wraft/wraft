defmodule WraftDoc.WaitingListsTest do
  @moduledoc false
  use WraftDoc.DataCase, async: true
  @moduletag :waiting_list

  alias WraftDoc.WaitingLists
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDoc.Workers.EmailWorker

  @valid_params %{
    "first_name" => "first name",
    "last_name" => "last name",
    "email" => "sample@gmail.com"
  }

  @invalid_params %{}

  describe "join_waiting_list/1" do
    test "user successfully added to the waiting list" do
      {:ok, %WaitingList{} = waitlist} = WaitingLists.join_waiting_list(@valid_params)

      assert waitlist.first_name == @valid_params["first_name"]
      assert waitlist.last_name == @valid_params["last_name"]
      assert waitlist.email == @valid_params["email"]
      assert waitlist.status == :pending
    end

    test "returns error changeset for failure adding to waiting list" do
      {:error, changeset} = WaitingLists.join_waiting_list(@invalid_params)

      assert %{
               email: ["can't be blank"],
               first_name: ["can't be blank"],
               last_name: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "waitlist_confirmation_email/1" do
    test "creates email background job for valid user_name and email" do
      user_name = "#{@valid_params["first_name"]} #{@valid_params["last_name"]}"

      {:ok, job} =
        WaitingLists.waitlist_confirmation_email(%{
          first_name: "first name",
          last_name: "last name",
          email: "sample@gmail.com"
        })

      assert job.args == %{
               user_name: user_name,
               email: @valid_params["email"]
             }

      assert_enqueued(
        worker: EmailWorker,
        args: %{
          email: job.args.email,
          user_name: job.args.user_name
        },
        queue: :mailer
      )
    end
  end
end
