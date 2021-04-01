defmodule WraftDoc.Repo.Migrations.CreateUserRole do
  use Ecto.Migration

  def up do
   create table(:user_role) do
    add :uuid, :uuid, null: false, autogenerate: true
    add :user_id, references(:user,on_delete: :delete_all)
    add :role_id, references(:role, on_delete: :delete_all)
    timestamps()

   end

   execute """
   INSERT INTO public.user_role (role_id,user_id,uuid, inserted_at, updated_at) SELECT role_id, id, '#{Ecto.UUID.autogenerate()}', '#{NaiveDateTime.local_now()}', '#{NaiveDateTime.local_now()}'  FROM public.user;
   """

  end
  def down do
    drop table(:user_role)
  end
end
