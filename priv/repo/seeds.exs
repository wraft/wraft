# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Starter.Repo.insert!(%Starter.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Starter.UserManagement.Roles
alias Starter.Repo
import Plug

#Populate database with roles
%Starter.UserManagement.Roles{name: "admin", admin: true} |> Starter.Repo.insert!
%Starter.UserManagement.Roles{name: "user", admin: false} |> Starter.Repo.insert!
