# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     WraftDoc.Repo.insert!(%WraftDoc.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias WraftDoc.{
  Repo,
  Account,
  Account.Role,
  Account.User,
  Account.Profile,
  Document.Engine
}

import Plug

# Populate database with roles
%Role{name: "admin"} |> Repo.insert!()
%Role{name: "user"} |> Repo.insert!()

%{id: id} = Role |> Repo.get_by(name: "admin")

user_params = %{
  name: "Admin",
  email: "admin@wraftdocs.com",
  role_id: id,
  email_verify: true,
  password: "Admin@WraftDocs"
}

user = %User{} |> User.changeset(user_params) |> Repo.insert!()
%Profile{name: "Admin", user_id: user.id} |> Repo.insert!()
# Populate engine
%Engine{name: "PDF"} |> Repo.insert!()
%Engine{name: "LaTex"} |> Repo.insert!()
%Engine{name: "Pandoc"} |> Repo.insert!()
