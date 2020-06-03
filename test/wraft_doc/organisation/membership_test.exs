defmodule WraftDoc.Enterprise.MembershipTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Enterprise.Membership}

  @valid_attrs %{
    start_date: Timex.now(),
    end_date: Timex.now() |> Timex.shift(days: 30),
    plan_duration: 14
  }

  @invalid_attrs %{start_date: ""}

  describe "changeset/2" do
    test "valid changeset with valid attributes" do
      plan = insert(:plan)
      organisation = insert(:organisation)
      params = @valid_attrs |> Map.merge(%{organisation_id: organisation.id, plan_id: plan.id})
      changeset = Membership.changeset(%Membership{}, params)

      assert changeset.valid?
    end

    test "invalid changeset with invalid attributes" do
      changeset = Membership.changeset(%Membership{}, %{})

      refute changeset.valid?
    end

    test "organisation unique constraint" do
      plan = insert(:plan)
      organisation = insert(:organisation)
      insert(:membership, organisation: organisation, plan: plan)
      params = @valid_attrs |> Map.merge(%{organisation_id: organisation.id, plan_id: plan.id})
      {:error, changeset} = Membership.changeset(%Membership{}, params) |> Repo.insert()

      assert "You already have a membership.!" in errors_on(changeset, :plan_id)
    end
  end

  describe "update_changeset/2" do
    test "valid update changeset with valid attrs" do
      membership = insert(:membership)
      params = @valid_attrs |> Map.put(:plan_duration, 30)
      changeset = Membership.update_changeset(membership, params)

      assert changeset.valid?
    end

    # test "valid update changeset with valid change in end_date only" do
    #   membership = insert(:membership)
    #   changeset = Membership.update_changeset(membership, %{end_date: Timex.now()})

    #   assert changeset.valid?
    # end

    # test "valid update changeset with valid change in start_date only" do
    #   membership = insert(:membership)
    #   start_date = Timex.now() |> Timex.shift(days: 1)
    #   changeset = Membership.update_changeset(membership, %{start_date: start_date})
    #   assert changeset.valid?
    # end

    test "update changeset with invalid change in plan_duration" do
      membership = insert(:membership)
      changeset = Membership.update_changeset(membership, %{plan_duration: 1})

      refute changeset.valid?
    end

    test "update changeset with invalid attrs" do
      membership = insert(:membership)
      changeset = Membership.update_changeset(membership, @invalid_attrs)
      refute changeset.valid?
    end
  end

  describe "expired_changeset/1" do
    test "expired changeset returns valid changeset" do
      membership = insert(:membership)
      changeset = Membership.expired_changeset(membership)
      assert changeset.valid?
    end
  end
end
