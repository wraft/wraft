# Test if the view renders edges correctly
alias WraftDoc.Repo
alias WraftDoc.Workflows.Workflow
alias WraftDocWeb.Api.V1.WorkflowView
import Ecto.Query

# Get workflow with edges preloaded
workflow =
  Workflow
  |> limit(1)
  |> Repo.one()
  |> Repo.preload([[jobs: :credentials], :triggers, :edges])

IO.puts("Workflow: #{workflow.name}")
IO.puts("Jobs: #{length(workflow.jobs)}")
IO.puts("Edges: #{length(workflow.edges)}")

# Render using the view
rendered = WorkflowView.render("workflow_detail.json", %{workflow: workflow})

IO.puts("\nRendered JSON:")
IO.inspect(rendered, pretty: true, limit: :infinity)

IO.puts("\nEdges in rendered JSON:")
IO.inspect(rendered.edges, pretty: true)
