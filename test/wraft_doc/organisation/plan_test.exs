defmodule WraftDoc.Enterprise.PlanTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise
  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Plan, Repo}

  @valid_attrs %{
    "name" => "Basic",
    "description" => "Basic plan",
    "plan_amount" => "200",
    "currency" => "USD",
    "billing_interval" => :year,
    "limits" => %{
      "instance_create" => 5,
      "content_type_create" => 10,
      "organisation_create" => 1,
      "organisation_invite" => 20
    },
    "trial_period" => %{"period" => "", "frequency" => ""}
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
    plan = insert(:plan)

    # Try to create another plan with the same name
    attrs = %{
      "name" => plan.name,
      "description" => "Basic plan",
      "plan_amount" => "200",
      "currency" => "USD",
      "billing_interval" => :year,
      "limits" => %{
        "instance_create" => 5,
        "content_type_create" => 10,
        "organisation_create" => 1,
        "organisation_invite" => 20
      },
      "trial_period" => %{"period" => "", "frequency" => ""}
    }

    {:error, changeset} = %Plan{} |> Plan.changeset(attrs) |> Repo.insert()

    name_errors = errors_on(changeset, :name)

    assert "A plan with the same name and billing interval already exists!" in name_errors
  end
end
