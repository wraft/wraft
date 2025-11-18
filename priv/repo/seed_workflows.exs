# Script to seed workflows without starting the Phoenix server
# Run with: mix run priv/repo/seed_workflows.exs

alias WraftDoc.Repo
alias WraftDoc.Account.User
alias WraftDoc.Enterprise.Organisation
alias WraftDoc.Seed

require Logger

Logger.info("🌱 Seeding workflows...")

# Get first user and org
user = Repo.get_by!(User, email: "wraftuser@gmail.com")
organisation = Organisation |> Repo.all() |> List.first()

if organisation do
  user = Map.put(user, :current_org_id, organisation.id)

  # Seed the workflows
  Seed.seed_dag_workflow(user, organisation)

  Logger.info("✅ Workflow seeding completed!")
  Logger.info("📊 Total workflows: #{Repo.aggregate(WraftDoc.Workflows.Workflow, :count)}")
else
  Logger.error("❌ No organisation found! Please run full seeds first.")
end
