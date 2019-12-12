# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ExStarter.Repo.insert!(%ExStarter.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias ExStarter.UserManagement.Role
alias ExStarter.Repo
import Plug

# Populate database with roles
%ExStarter.UserManagement.Role{name: "admin", admin: true} |> ExStarter.Repo.insert!()
%ExStarter.UserManagement.Role{name: "user", admin: false} |> ExStarter.Repo.insert!()
