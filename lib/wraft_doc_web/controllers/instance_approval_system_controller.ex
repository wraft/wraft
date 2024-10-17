defmodule WraftDocWeb.Api.V1.InstanceApprovalSystemController do
  @moduledoc """
  Controller module for Instance approval system
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized,
    index: "instance_approval_system:show",
    instances_to_approve: "instance_approval_system:show"

  alias WraftDoc.Document

  def swagger_definitions do
    %{
      Instance:
        swagger_schema do
          title("Content")
          description("A content, which is then used to generate the out files.")

          properties do
            id(:string, "The ID of the content", required: true)
            instance_id(:string, "A unique ID generated for the content")
            raw(:string, "Raw data of the content")
            serialized(:map, "Serialized data of the content")
            build(:string, "URL of the build document")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            instance_id: "OFFL01",
            raw: "Content",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            build: "/organisations/f5837766-573f-427f-a916-cf39a3518c7b/OFFL01/OFFLET-v1.pdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ApprovalSystem:
        swagger_schema do
          title("ApprovalSystem")
          description("A ApprovalSystem")

          properties do
            pre_state(Schema.ref(:State))
            post_state(Schema.ref(:State))
            approver(Schema.ref(:User))

            inserted_at(:string, "When was the approval_system inserted", format: "ISO-8601")
            updated_at(:string, "When was the approval_system last updated", format: "ISO-8601")
          end

          example(%{
            instance: %{id: "0sdf21d12sdfdfdf"},
            pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
            post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
            approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      State:
        swagger_schema do
          title("State")
          description("States of content")

          properties do
            id(:string, "States id")
            state(:string, "State of the content")
          end
        end,
      User:
        swagger_schema do
          title("User")
          description("A user of the application")

          properties do
            id(:string, "The ID of the user", required: true)
            name(:string, "Users name", required: true)
            email(:string, "Users email", required: true)
            email_verify(:boolean, "Email verification status")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "John Doe",
            email: "email@xyz.com",
            email_verify: true,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      InstanceApprovalSystem:
        swagger_schema do
          title("Instance approval system")
          description("Approval system to follow by an instance")

          properties do
            id(:string, "id")
            flag(:boolean, "Flag to specify approved or not")
            order(:integer, "Order of the pre state of the approval system")
            instance(Schema.ref(:Instance))
            approval_system(Schema.ref(:ApprovalSystem))
          end

          example(%{
            id: "26ds-s4fd5-sd1f541-sdf415sd",
            flag: false,
            order: 1,
            instance: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              build: "/organisations/f5837766-573f-427f-a916-cf39a3518c7b/OFFL01/OFFLET-v1.pdf",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            approval_system: %{
              instance: %{id: "0sdf21d12sdfdfdf"},
              pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
              post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
              approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      InstanceApprovalSystems:
        swagger_schema do
          title("Instance approval systems")
          description("List of all instance approval system")
          type(:array)
          items(Schema.ref(:InstanceApprovalSystem))
        end,
      InstanceApprovalSystemIndex:
        swagger_schema do
          title("Instance approval system indes")
          description("Page containis all instance approval systems")

          properties do
            instance_approval_systems(Schema.ref(:InstanceApprovalSystems))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total pages")
            total_entries(:integer, "Total entries")
          end

          example(%{
            instance_approval_systems: [
              %{
                id: "26ds-s4fd5-sd1f541-sdf415sd",
                flag: false,
                order: 1,
                instance: %{
                  id: "1232148nb3478",
                  instance_id: "OFFL01",
                  raw: "Content",
                  serialized: %{title: "Title of the content", body: "Body of the content"},
                  build:
                    "/organisations/f5837766-573f-427f-a916-cf39a3518c7b/OFFL01/OFFLET-v1.pdf",
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                approval_system: %{
                  instance: %{id: "0sdf21d12sdfdfdf"},
                  pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
                  post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
                  approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 1,
            total_entries: 1
          })
        end
    }
  end

  swagger_path :index do
    get("/users/{id}/instance-approval-systems")
    summary("List all instance approval systems")
    description("Api to list all approval system under an user")

    parameters do
      id(:path, :string, "User id", required: true)
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:InstanceApprovalSystemIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def index(conn, %{"id" => user_id} = params) do
    with %{
           entries: instance_approval_systems,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_approval_system_index(user_id, params) do
      render(conn, "index.json", %{
        instance_approval_systems: instance_approval_systems,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      })
    end
  end

  swagger_path :instances_to_approve do
    get("/users/instance-approval-systems")
    summary("list all instance approval system under an user")
    description("Api to list all approval system under an user")

    parameters do
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:InstanceApprovalSystemIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def instances_to_approve(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: instance_approval_systems,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_approval_system_index(current_user, params) do
      render(conn, "index.json", %{
        instance_approval_systems: instance_approval_systems,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      })
    end
  end
end
