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
alias WraftDoc.Account.Role
alias WraftDoc.Repo
import Plug

# Populate database with roles
%Role{name: "admin"} |> Repo.insert!()
%Role{name: "user"} |> Repo.insert!()
