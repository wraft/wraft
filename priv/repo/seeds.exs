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
alias Starter.User_management.Roles
alias Starter.Repo
import Plug

#Populate database with roles
%Starter.User_management.Roles{name: "admin", admin: true} |> Starter.Repo.insert!
%Starter.User_management.Roles{name: "user", admin: false} |> Starter.Repo.insert!
