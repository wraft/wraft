# defmodule WraftDoc.Repo.Migrations.ApprovalSystemTrigger do
#   use Ecto.Migration

#   def up do
#     # Create a function that broadcasts row changes
#     execute "
#       CREATE OR REPLACE FUNCTION broadcast_changes()
#       RETURNS trigger AS $$
#       DECLARE
#         current_row RECORD;
#       BEGIN
#         IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
#           current_row := NEW;
#         ELSE
#           current_row := OLD;
#         END IF;
#         IF (TG_OP = 'INSERT') THEN
#           OLD := NEW;
#         END IF;
#       PERFORM pg_notify(
#           'approval_system_changes',
#           json_build_object(
#             'table', TG_TABLE_NAME,
#             'type', TG_OP,
#             'id', current_row.id,
#             'new_row_data', row_to_json(NEW),
#             'old_row_data', row_to_json(OLD)
#           )::text
#         );
#       RETURN current_row;
#       END;
#       $$ LANGUAGE plpgsql;"

#     execute "
#       CREATE TRIGGER notify_approval_system_trigger
#       AFTER INSERT OR UPDATE OR DELETE
#       ON approval_system
#       FOR EACH ROW
#       EXECUTE PROCEDURE broadcast_changes();"
#   end

#   def down do
#     execute "DROP TRIGGER notify_approval_system_trigger  "
#   end
# end
