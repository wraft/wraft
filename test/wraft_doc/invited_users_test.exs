defmodule WraftDoc.InvitedUsersTest do
  use WraftDoc.DataCase

  import ExUnit.CaptureLog
  import WraftDoc.Factory

  alias WraftDoc.InvitedUsers
  alias WraftDoc.InvitedUsers.InvitedUser

  describe "create_or_update_invited_user/3 when user doesnt exist" do
    test "creates a new invited user and returns :ok with valid params" do
      %{id: organisation_id} = insert(:organisation)
      assert :ok = InvitedUsers.create_or_update_invited_user("user@xyz.com", organisation_id)

      assert %InvitedUser{} =
               Repo.get_by(
                 InvitedUser,
                 email: "user@xyz.com",
                 organisation_id: organisation_id
               )
    end

    test "adds an error log with invalid params" do
      %{id: organisation_id} = insert(:organisation)

      capture_log(
        [level: :error],
        fn ->
          assert :ok = InvitedUsers.create_or_update_invited_user("invalid", organisation_id)
        end
      ) =~ "InvitedUser Create/Update failed"
    end
  end

  describe "create_or_update_invited_user/3 when user exists" do
    test "updates user status and returns :ok with valid status" do
      invited_user = insert(:invited_user)

      assert :ok =
               InvitedUsers.create_or_update_invited_user(
                 invited_user.email,
                 invited_user.organisation_id,
                 "joined"
               )

      assert %InvitedUser{status: "joined"} =
               Repo.get_by(
                 InvitedUser,
                 email: invited_user.email,
                 organisation_id: invited_user.organisation_id
               )
    end

    test "adds an error log with invalid status" do
      invited_user = insert(:invited_user)

      capture_log(
        [level: :error],
        fn ->
          assert :ok =
                   InvitedUsers.create_or_update_invited_user(
                     invited_user.email,
                     invited_user.organisation_id,
                     "invalid"
                   )
        end
      ) =~ "InvitedUser Create/Update failed"
    end
  end

  describe "get_invited_user/2" do
    test "returns %InvitedUser{} with valid email-organisation_id combo" do
      %{id: id, email: email, organisation_id: organisation_id} = insert(:invited_user)

      assert %InvitedUser{id: ^id, email: ^email, organisation_id: ^organisation_id} =
               InvitedUsers.get_invited_user(email, organisation_id)
    end

    test "returns nil with invalid data" do
      assert nil == InvitedUsers.get_invited_user("test@invalid.com", Faker.UUID.v4())
    end
  end
end
