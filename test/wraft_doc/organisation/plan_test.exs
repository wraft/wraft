defmodule WraftDoc.Enterprise.PlanTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Plan, Repo}

  @valid_attrs %{
    name: "Basic",
    description: "A free plan, with only basic features",
    yearly_amount: 0,
    monthly_amount: 0
  }

  test "changeset with valid attributes" do
    changeset = Plan.changeset(%Plan{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Plan.changeset(%Plan{}, %{})
    refute changeset.valid?
  end

  test "organisation name unique constraint" do
    insert(:plan, @valid_attrs)
    {:error, changeset} = %Plan{} |> Plan.changeset(@valid_attrs) |> Repo.insert()

    assert "A plan with the same name exists.!" in errors_on(changeset, :name)
  end
end
