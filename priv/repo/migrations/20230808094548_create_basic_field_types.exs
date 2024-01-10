defmodule WraftDoc.Repo.Migrations.CreateBasicFieldTypes do
  use Ecto.Migration
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Repo
  alias WraftDoc.Validations.Validation

  def up do
    basic_field_types = [
      %{
        name: "String",
        meta: %{"allowed validations": ["required", "min_length", "max_length", "regex"]},
        description: "A string field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Text",
        meta: %{"allowed validations": ["required"]},
        description: "A text field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Email",
        meta: %{"allowed validations": ["required", "regex"]},
        description: "An email field",
        validations: [
          %Validation{
            validation: %{rule: "email"},
            error_message: "Invalid Email"
          }
        ],
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Date",
        meta: %{"allowed validations": ["required", "date_min", "date_max", "date_range"]},
        description: "A date field",
        validations: [
          %Validation{
            validation: %{rule: "date"},
            error_message: "Invalid Date"
          }
        ],
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Time",
        meta: %{"allowed validations": ["required"]},
        description: "A time field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Radio Button",
        meta: %{"allowed validations": ["required", "options"]},
        description: "A radio button field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Drop Down",
        meta: %{"allowed validations": ["required", "options"]},
        description: "A drop down field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Checkbox",
        meta: %{"allowed validations": ["required", "options"]},
        description: "A checkbox field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "File Input",
        meta: %{"allowed validations": ["required", "file_size"]},
        description: "A file input field",
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Url",
        meta: %{"allowed validations": ["required", "regex"]},
        description: "An url field",
        validations: [
          %Validation{
            validation: %{rule: "url"},
            error_message: "Invalid Url"
          }
        ],
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Phone Number",
        meta: %{"allowed validations": ["required"]},
        description: "A phone number field",
        validations: [
          %Validation{
            validation: %{rule: "phone_number"},
            error_message: "Invalid Phone Number"
          }
        ],
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      },
      %{
        name: "Decimal",
        meta: %{"allowed validations": ["required"]},
        description: "A decimal field",
        validations: [
          %Validation{
            validation: %{rule: "decimal"},
            error_message: "Invalid Decimal Format"
          }
        ],
        inserted_at: NaiveDateTime.local_now(),
        updated_at: NaiveDateTime.local_now()
      }
    ]

    Repo.insert_all(FieldType, basic_field_types)
  end

  def down do
    FieldType |> Repo.all() |> Enum.each(&Repo.delete(&1))
  end
end
