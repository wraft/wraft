# defmodule WraftDoc.Repo.Migrations.BrodcastNotificationContentType do
#   use Ecto.Migration

#   def change do
#      execute """
#      CREATE OR REPLACE FUNCTION notify_content_type_changes()
#      RETURNS trigger AS $$
#      DECLARE
#        current_row RECORD;
#      BEGIN
#        IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
#          current_row := NEW;
#        ELSE
#          current_row := OLD;
#        END IF;
#        PERFORM pg_notify(
#          'content_type_changes',
#          json_build_object(
#            'table', TG_TABLE_NAME,
#            'type', TG_OP,
#            'id', current_row.id,
#            'data', row_to_json(current_row)
#          )::text
#        );
#        RETURN current_row;
#      END;
#      $$ LANGUAGE plpgsql;
#      """,
#      "DROP FUNCTION IF EXISTS notify_content_type_changes()"

#      execute """
#      CREATE TRIGGER notify_content_type_changes
#      AFTER INSERT OR UPDATE OR DELETE
#      ON content_type
#      FOR EACH ROW
#      EXECUTE PROCEDURE notify_content_type_changes();
#      """
#   end
# end
