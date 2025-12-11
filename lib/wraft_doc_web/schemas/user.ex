defmodule WraftDocWeb.Schemas.User do
  @moduledoc """
  Schema for User request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule UserLoginRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User Login",
      description: "A user log in to the application",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "User's email"},
        password: %Schema{type: :string, description: "User's password"}
      },
      required: [:email, :password],
      example: %{
        email: "wraftuser@gmail.com",
        password: "password"
      }
    })
  end

  defmodule UserGoogleLoginRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User Google Login",
      description: "A user log in to the application using Google authentication",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Google Auth Token"}
      },
      required: [:token],
      example: %{
        token: "Asdlkqweb.Khgqiwue132.xcli123"
      }
    })
  end

  defmodule User do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User",
      description: "A user of the application",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the user"},
        name: %Schema{type: :string, description: "Users name"},
        email: %Schema{type: :string, description: "Users email"},
        email_verify: %Schema{type: :boolean, description: "Email verification status"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        }
      },
      required: [:id, :name, :email],
      example: %{
        id: "1232148nb3478",
        name: "John Doe",
        email: "email@xyz.com",
        email_verify: true,
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule LoggedInUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Logged in user",
      description: "A user of the application who just logged in or registered",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the user"},
        name: %Schema{type: :string, description: "Users name"},
        email: %Schema{type: :string, description: "Users email"},
        email_verify: %Schema{type: :boolean, description: "Email verification status"},
        profile_pic: %Schema{type: :string, description: "URL of the user's profile picture"},
        organisation_id: %Schema{type: :string, description: "User's current organisation ID"},
        roles: %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "Roles of the user"
        },
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        }
      },
      required: [:id, :name, :email, :organisation_id, :roles],
      example: %{
        id: "1232148nb3478",
        name: "John Doe",
        email: "email@xyz.com",
        email_verify: true,
        profile_pic: "www.minio.com/users/johndoe.jpg",
        organisation_id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
        roles: [%{id: "756f1fa1-9657-4166-b372-21e8135aeaf1", name: "superadmin"}],
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule UserToken do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User and token",
      description: "User details with the generated JWT token for authentication",
      type: :object,
      properties: %{
        access_token: %Schema{
          type: :string,
          description: "JWT access token for authenticating the user"
        },
        refresh_token: %Schema{
          type: :string,
          description: "JWT refresh token for refreshing access token"
        },
        user: LoggedInUser
      },
      required: [:access_token, :refresh_token],
      example: %{
        access_token: "Asdlkqweb.Khgqiwue132.xcli123",
        refresh_token: "Asdlkqweb.Khgqiwue132.xcli123",
        user: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          profile_pic: "www.minio.com/users/johndoe.jpg",
          organisation_id: "466f1fa1-9657-4166-b372-21e8135aeaf1",
          roles: [%{id: "756f1fa1-9657-4166-b372-21e8135aeaf1", name: "superadmin"}],
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule UserSearch do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User Search",
      description: "A user of the application",
      type: :object,
      properties: %{
        users: %Schema{type: :array, items: User},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        page_number: 1,
        total_entries: 2,
        total_pages: 1,
        users: [
          %{
            id: "af2cf1c6-f342-4042-8425-6346e9fd6c44",
            name: "Richard Hendricks",
            profile_pic: "www.minio.com/users/johndoe.jpg"
          }
        ]
      }
    })
  end

  defmodule CurrentUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Current User",
      description: "Currently loged in user",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the user"},
        name: %Schema{type: :string, description: "Users name"},
        email: %Schema{type: :string, description: "Users email"},
        email_verify: %Schema{type: :boolean, description: "Email verification status"},
        organisation_id: %Schema{type: :string, description: "ID of the user's oranisation"},
        profile_pic: %Schema{type: :string, description: "User's profile pic URL"},
        role: %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "User's role objects"
        },
        role_names: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "User's role names"
        },
        permissions: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "User's permissions"
        },
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        }
      },
      required: [:id, :name, :email, :role],
      example: %{
        id: "1232148nb3478",
        name: "John Doe",
        email: "email@xyz.com",
        email_verify: true,
        roles: [%{id: "1232148nb3478", name: "editor"}],
        role_name: ["editor"],
        permissions: ["asset:show"],
        profile_pic: "www.aws.com/users/johndoe.jpg",
        organisation_id: "jn14786914qklnqw",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ShowCurrentUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show Current User",
      description: "Currently loged in user",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the user"},
        name: %Schema{type: :string, description: "Users name"},
        email: %Schema{type: :string, description: "Users email"},
        email_verify: %Schema{type: :boolean, description: "Email verification status"},
        organisation_id: %Schema{type: :string, description: "ID of the user's oranisation"},
        profile_pic: %Schema{type: :string, description: "User's profile pic URL"},
        role: %Schema{type: :string, description: "User's role"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        }
      },
      required: [:id, :name, :email],
      example: %{
        id: "1232148nb3478",
        name: "John Doe",
        email: "email@xyz.com",
        email_verify: true,
        role: "user",
        profile_pic: "www.aws.com/users/johndoe.jpg",
        organisation_id: "jn14786914qklnqw",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ActivityStream do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Activity Stream",
      description: "Activity stream object",
      type: :object,
      properties: %{
        action: %Schema{type: :string, description: "Activity action"},
        object: %Schema{type: :string, description: "Activity Object"},
        meta: %Schema{type: :object, description: "Meta of the activity"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        },
        actor: %Schema{type: :string, description: "Actor name"},
        object_details: %Schema{type: :object, description: "Name and ID of the object"}
      }
    })
  end

  defmodule ActivityStreamIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Activity Stream Index",
      description: "Activity stream index",
      type: :object,
      properties: %{
        activities: %Schema{type: :array, items: ActivityStream},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        activities: [
          %{
            action: "create",
            object: "Layout:1",
            meta: %{from: "", to: %{name: "Layout 1"}},
            inserted_at: "2020-01-21T14:00:00Z",
            actor: "John Doe",
            object_details: %{name: "Layout 1", id: "jhg1348561234nkjqwd89"}
          },
          %{
            action: "delete",
            object: "Layout:1,Layout 1",
            meta: %{},
            inserted_at: "2020-01-21T14:00:00Z",
            actor: "John Doe",
            object_details: %{name: "Layout 1"}
          }
        ],
        page_number: 1,
        total_pages: 10,
        total_entries: 100
      }
    })
  end

  defmodule GeneratePasswordSetTokenRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Generate password set token request",
      description: "Request to generate password set token",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"},
        first_time_setup: %Schema{type: :boolean, description: "First time setting password"}
      },
      required: [:email],
      example: %{
        email: "user@wraft.com",
        first_time_setup: true
      }
    })
  end

  defmodule ResetPasswordRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Reset password request",
      description: "Request to reset password",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Token has given in email"},
        password: %Schema{type: :string, description: "New password to update"}
      },
      required: [:token, :password],
      example: %{
        token:
          "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf",
        password: "new password"
      }
    })
  end

  defmodule AuthToken do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Auth token",
      description: "Response for reset password request",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Response Info"}
      },
      example: %{
        info: "A password reset link has been sent to your email.!"
      }
    })
  end

  defmodule TokenVerifiedInfo do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Token verified info",
      description: "Token verified info",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      }
    })
  end

  defmodule UpdatePasswordRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Password to update",
      description: "Request to update password",
      type: :object,
      properties: %{
        current_password: %Schema{type: :string, description: "Current password"},
        password: %Schema{type: :string, description: "Password to update"}
      },
      required: [:current_password, :password]
    })
  end

  defmodule SetPasswordRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Set Password",
      description: "Set password for first time.",
      type: :object,
      properties: %{
        password: %Schema{type: :string, description: "User's password"},
        confirm_password: %Schema{type: :string, description: "Confirm password"},
        token: %Schema{type: :string, description: "set password token"}
      },
      required: [:password, :confirm_password, :token],
      example: %{
        password: "password",
        confirm_password: "password",
        token: "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
      }
    })
  end

  defmodule EmailTokenVerifiedInfo do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Email Token verified info",
      description: "Email Token verified info",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"},
        verification_status: %Schema{type: :boolean, description: "Verification Status"}
      }
    })
  end

  defmodule ResendEmailTokenRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Resend Email Token",
      description: "Resend token for account verification",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Token is given in email"}
      },
      required: [:token],
      example: %{
        token: "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
      }
    })
  end

  defmodule OrganisationByUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation by user",
      description: "Organisation spec for a given user",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "id of the organisation"},
        name: %Schema{type: :string, description: "name of the organisation"},
        logo: %Schema{type: :string, description: "logo of the organisation"}
      }
    })
  end

  defmodule OrganisationByUserIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation by user index",
      description: "List Organisations by a user",
      type: :object,
      properties: %{
        organisations: %Schema{type: :array, items: OrganisationByUser}
      },
      example: %{
        organisations: [
          %{
            id: "5c69ce59-5b38-4a63-ab34-17b29d157887",
            name: "Invited org",
            logo: "/logo.jpg"
          },
          %{
            id: "25af23bc-47b4-4560-a1b1-e41b31020733",
            name: "Personal",
            logo: "/logo_personal.jpg"
          }
        ]
      }
    })
  end

  defmodule RefreshTokenRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Refresh Token Request",
      description: "Refresh Token to get new pair of tokens",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Refresh Token"}
      },
      required: [:token],
      example: %{
        token: "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
      }
    })
  end

  defmodule RefreshToken do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Refresh Token",
      description: "New pair of access token and refresh token",
      type: :object,
      properties: %{
        access_token: %Schema{type: :string, description: "Access Token"},
        refresh_token: %Schema{type: :string, description: "Refresh Token"}
      },
      example: %{
        access_token:
          "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf",
        refresh_token:
          "asddff23a2ds_f3asdf3a21fds23f2as32f3as3f213a2df3s2f3a213sad12f13df13adsf-21f1d3sf"
      }
    })
  end

  defmodule CheckEmailRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Check Email",
      description: "Check Email",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"}
      },
      required: [:email],
      example: %{
        email: "user@wraft.com"
      }
    })
  end

  defmodule SetPasswordResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Set Password Info",
      description: "Response for set password",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      example: %{
        info: "Success"
      }
    })
  end
end
