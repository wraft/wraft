# Test script to check if workflow edges are loaded properly
alias WraftDoc.Repo
alias WraftDoc.Workflows.{Workflow, WorkflowJob, WorkflowEdge}
alias WraftDoc.Account.User
alias WraftDoc.Enterprise.Membership
import Ecto.Query

# Get a user
user = Repo.get_by(User, email: "wraftuser@gmail.com")
IO.puts("User: #{user.email}")
IO.puts("Current Org: #{inspect(user.current_org_id)}")

# Get user's organization from membership
membership =
  Membership
  |> where([m], m.user_id == ^user.id)
  |> limit(1)
  |> Repo.one()

org_id = membership.organisation_id
IO.puts("Org from membership: #{org_id}")

# Update user's current_org_id if nil
if is_nil(user.current_org_id) do
  user
  |> Ecto.Changeset.change(%{current_org_id: org_id})
  |> Repo.update!()

  IO.puts("Updated user's current_org_id to #{org_id}")
end

user = %{user | current_org_id: org_id}

# Get first workflow
workflow =
  Workflow
  |> where([w], w.organisation_id == ^org_id)
  |> limit(1)
  |> Repo.one()

IO.puts("\nWorkflow ID: #{workflow.id}")
IO.puts("Workflow Name: #{workflow.name}")

# Check edges in DB for this workflow
edges =
  WorkflowEdge
  |> where([e], e.workflow_id == ^workflow.id)
  |> Repo.all()

IO.puts("\nEdges in DB: #{length(edges)}")

for edge <- edges do
  IO.puts(
    "  - #{edge.id}: #{edge.source_job_id} -> #{edge.target_job_id} (#{edge.condition_type})"
  )
end

# Now use the Workflows context function (same as API)
alias WraftDoc.Workflows
loaded_workflow = Workflows.get_workflow(user, workflow.id)

IO.puts("\nLoaded via Workflows.get_workflow:")
IO.puts("  Jobs loaded: #{length(loaded_workflow.jobs)}")
IO.puts("  Edges loaded: #{length(loaded_workflow.edges)}")

for edge <- loaded_workflow.edges do
  IO.puts("  - Edge: #{edge.source_job_id} -> #{edge.target_job_id} (#{edge.condition_type})")
end
