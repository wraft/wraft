# Simple check of edges
alias WraftDoc.Repo
alias WraftDoc.Workflows.{Workflow, WorkflowEdge}
import Ecto.Query

# Get any workflow
workflow = Workflow |> limit(1) |> Repo.one()
IO.puts("Workflow: #{workflow.name} (#{workflow.id})")

# Get edges for this workflow
edges =
  WorkflowEdge
  |> where([e], e.workflow_id == ^workflow.id)
  |> Repo.all()

IO.puts("\nDirect DB query - Edges: #{length(edges)}")

for edge <- edges do
  IO.puts("  #{edge.source_job_id} -> #{edge.target_job_id} (#{edge.condition_type})")
end

# Now preload edges
workflow_with_edges = workflow |> Repo.preload(:edges)
IO.puts("\nWith preload - Edges: #{length(workflow_with_edges.edges)}")

for edge <- workflow_with_edges.edges do
  IO.puts("  #{edge.source_job_id} -> #{edge.target_job_id} (#{edge.condition_type})")
end
