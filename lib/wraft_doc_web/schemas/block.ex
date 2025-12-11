defmodule WraftDocWeb.Schemas.Block do
  @moduledoc """
  Schema for Block request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule BlockRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Block Request",
      description: "A block to Be created to add to instances",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Block name"},
        btype: %Schema{type: :string, description: "Block type"},
        dataset: %Schema{type: :object, description: "Dataset for creating charts"},
        api_route: %Schema{type: :string, description: "Api route to generate chart"},
        endpoint: %Schema{type: :string, description: "name of the endpoint going to choose"}
      },
      required: [:name, :btype, :dataset],
      example: %{
        name: "Farming",
        btype: "pie",
        api_route: "http://localhost:8080/chart",
        endpoint: "blocks_api",
        dataset: %{
          data: [
            %{
              value: 10,
              label: "January"
            },
            %{
              value: 20,
              label: "February"
            },
            %{
              value: 5,
              label: "March"
            },
            %{
              value: 60,
              label: "April"
            },
            %{
              value: 80,
              label: "May"
            },
            %{
              value: 70,
              label: "June"
            },
            %{
              value: 90,
              label: "Julay"
            }
          ],
          width: 512,
          height: 512,
          backgroundColor: "transparent",
          format: "svg",
          type: "pie"
        }
      }
    })
  end

  defmodule Block do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Block",
      description: "A Block",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Block name"},
        btype: %Schema{type: :string, description: "Block type"},
        dataset: %Schema{type: :object, description: "Dataset for creating charts"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        },
        api_route: %Schema{type: :string, description: "Api route to generate chart"},
        endpoint: %Schema{type: :string, description: "name of the endpoint going to choose"},
        input: %Schema{type: :string, description: "Input file url"},
        tex_chart: %Schema{type: :string, description: "Latex code of the pie chart"}
      },
      required: [:name, :btype, :dataset],
      example: %{
        name: "Farming",
        description: "Description about block",
        btype: "pie",
        api_route: "http://localhost:8080/chart",
        endpoint: "blocks_api",
        file_url:
          "/home/sadique/Documents/org.functionary/go/src/blocks_api/002dc916-4444-4072-a8aa-85a32c5a65ea.svg",
        tex_chart: "\pie [rotate=180]{80/january}",
        input: "organisations/7df19bba-9196-4e9e-b1b6-8651f4566ff0/block_input/name.csv",
        dataset: %{
          data: [
            %{
              value: 10,
              label: "January"
            },
            %{
              value: 20,
              label: "February"
            },
            %{
              value: 5,
              label: "March"
            },
            %{
              value: 60,
              label: "April"
            },
            %{
              value: 80,
              label: "May"
            },
            %{
              value: 70,
              label: "June"
            },
            %{
              value: 90,
              label: "Julay"
            }
          ],
          width: 512,
          height: 512,
          backgroundColor: "transparent",
          format: "svg",
          type: "pie"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end
end
