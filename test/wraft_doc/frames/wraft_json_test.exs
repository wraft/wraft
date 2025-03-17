defmodule WraftJsonTest do
  use ExUnit.Case
  alias WraftDoc.Frames.WraftJson

  describe "valid case" do
    test "valid wraft.json passes validation" do
      valid_json = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "description" => "Technical & Commercial Proposal",
          "type" => "typst",
          "lastUpdated" => "2025-03-12"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "cover.typ",
              "path" => "cover.typ",
              "description" => "Cover page template"
            },
            %{
              "name" => "default.typst",
              "path" => "default.typst",
              "description" => "Default styling and configuration"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst",
              "description" => "Main template"
            }
          ],
          "assets" => [
            %{
              "name" => "logo",
              "path" => "assets/logo.svg",
              "description" => "Letterhead Logo"
            }
          ],
          "fonts" => [
            %{
              "fontName" => "IBM Plex Sans",
              "fontWeight" => "regular",
              "path" => "fonts/IBMPlexSans-Regular.ttf"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title",
            "description" => "Title of the document",
            "required" => true
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert :ok == WraftJson.validate_json(valid_json)
    end
  end

  describe "version validation" do
    test "invalid version format fails validation" do
      invalid_version = %{
        "version" => "1.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_version)
    end
  end

  describe "metadata validation" do
    test "missing required metadata fields fails validation" do
      missing_metadata_type = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft"
          # Missing type field
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(missing_metadata_type)
    end

    test "invalid document type fails validation" do
      invalid_doc_type = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          # Invalid type
          "type" => "word"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_doc_type)
    end
  end

  describe "package contents validation" do
    test "missing required files fails validation" do
      missing_required_files = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "cover.typ",
              "path" => "cover.typ"
            },
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            }
            # Missing template.typst
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(missing_required_files)
    end

    test "invalid file extension fails validation" do
      invalid_extension = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              # Invalid extension for typst
              "name" => "cover.docx",
              "path" => "cover.docx"
            },
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_extension)
    end
  end

  describe "rootFile validation" do
    test "rootFile not in packageContents fails validation" do
      invalid_root_file = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "cover.typ",
              "path" => "cover.typ"
            },
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          # This doesn't exist in rootFiles
          "rootFile" => "main.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_root_file)
    end
  end

  describe "fields validation" do
    test "select field without options fails validation" do
      select_without_options = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            # select type requires options
            "type" => "select",
            "name" => "Priority"
            # Missing options
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(select_without_options)
    end

    test "invalid field type fails validation" do
      invalid_field_type = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            # Invalid field type
            "type" => "image",
            "name" => "Logo"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_field_type)
    end
  end

  describe "buildSettings validation" do
    test "invalid output format fails validation" do
      invalid_output_format = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          # Invalid output format
          "outputFormat" => "html"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_output_format)
    end
  end

  describe "latex document type validation" do
    test "valid latex configuration passes validation" do
      valid_latex = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "Latex Document",
          "type" => "latex"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "main.tex",
              "path" => "main.tex"
            },
            %{
              "name" => "template.tex",
              "path" => "template.tex"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "main.tex",
          "outputFormat" => "pdf"
        }
      }

      assert :ok == WraftJson.validate_json(valid_latex)
    end

    test "invalid latex file extension fails validation" do
      invalid_latex_extension = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "Latex Document",
          "type" => "latex"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              # Invalid extension for latex
              "name" => "main.txt",
              "path" => "main.txt"
            },
            %{
              "name" => "template.tex",
              "path" => "template.tex"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "main.txt",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(invalid_latex_extension)
    end
  end

  describe "font validation" do
    test "valid font configuration passes validation" do
      valid_fonts = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ],
          "fonts" => [
            %{
              "fontName" => "IBM Plex Sans",
              "fontWeight" => "regular",
              "path" => "fonts/IBMPlexSans-Regular.ttf",
              "required" => true
            },
            %{
              "fontName" => "IBM Plex Sans",
              "fontWeight" => "bold",
              "path" => "fonts/IBMPlexSans-Bold.ttf"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert :ok == WraftJson.validate_json(valid_fonts)
    end

    test "missing required font fields fails validation" do
      missing_font_name = %{
        "version" => "1.0.0",
        "metadata" => %{
          "name" => "wraft",
          "type" => "typst"
        },
        "packageContents" => %{
          "rootFiles" => [
            %{
              "name" => "default.typst",
              "path" => "default.typst"
            },
            %{
              "name" => "template.typst",
              "path" => "template.typst"
            }
          ],
          "fonts" => [
            %{
              # Missing fontName
              "fontWeight" => "regular",
              "path" => "fonts/IBMPlexSans-Regular.ttf"
            }
          ]
        },
        "fields" => [
          %{
            "type" => "string",
            "name" => "Title"
          }
        ],
        "buildSettings" => %{
          "rootFile" => "default.typst",
          "outputFormat" => "pdf"
        }
      }

      assert {:error, _} = WraftJson.validate_json(missing_font_name)
    end
  end

  test "missing font path fails validation" do
    missing_font_path = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        "rootFiles" => [
          %{
            "name" => "default.typst",
            "path" => "default.typst"
          },
          %{
            "name" => "template.typst",
            "path" => "template.typst"
          }
        ],
        "fonts" => [
          %{
            "fontName" => "IBM Plex Sans",
            "fontWeight" => "regular"
            # Missing path
          }
        ]
      },
      "fields" => [
        %{
          "type" => "string",
          "name" => "Title"
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf"
      }
    }

    assert {:error, _} = WraftJson.validate_json(missing_font_path)
  end

  test "valid multi-select field passes validation" do
    valid_multiselect = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        "rootFiles" => [
          %{
            "name" => "default.typst",
            "path" => "default.typst"
          },
          %{
            "name" => "template.typst",
            "path" => "template.typst"
          }
        ]
      },
      "fields" => [
        %{
          "type" => "multiselect",
          "name" => "Categories",
          "options" => ["Technical", "Commercial", "Legal"]
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf"
      }
    }

    assert :ok = WraftJson.validate_json(valid_multiselect)
  end

  test "missing rootFiles array fails validation" do
    missing_rootfiles = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        # Missing rootFiles
        "assets" => [
          %{
            "name" => "logo",
            "path" => "assets/logo.svg"
          }
        ]
      },
      "fields" => [
        %{
          "type" => "string",
          "name" => "Title"
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf"
      }
    }

    assert {:error, _} = WraftJson.validate_json(missing_rootfiles)
  end

  test "date field type passes validation" do
    date_field = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        "rootFiles" => [
          %{
            "name" => "default.typst",
            "path" => "default.typst"
          },
          %{
            "name" => "template.typst",
            "path" => "template.typst"
          }
        ]
      },
      "fields" => [
        %{
          "type" => "date",
          "name" => "Submission Date"
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf"
      }
    }

    assert :ok = WraftJson.validate_json(date_field)
  end

  test "custom build settings passes validation" do
    custom_settings = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        "rootFiles" => [
          %{
            "name" => "default.typst",
            "path" => "default.typst"
          },
          %{
            "name" => "template.typst",
            "path" => "template.typst"
          }
        ]
      },
      "fields" => [
        %{
          "type" => "string",
          "name" => "Title"
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf",
        "customSettings" => %{
          "fontScale" => 1.2,
          "compactMode" => true,
          "margins" => %{
            "top" => 1.5,
            "bottom" => 1.5
          }
        }
      }
    }

    assert :ok = WraftJson.validate_json(custom_settings)
  end

  test "missing name in rootFile fails validation" do
    missing_name = %{
      "version" => "1.0.0",
      "metadata" => %{
        "name" => "wraft",
        "type" => "typst"
      },
      "packageContents" => %{
        "rootFiles" => [
          %{
            # Missing name
            "path" => "default.typst"
          },
          %{
            "name" => "template.typst",
            "path" => "template.typst"
          }
        ]
      },
      "fields" => [
        %{
          "type" => "string",
          "name" => "Title"
        }
      ],
      "buildSettings" => %{
        "rootFile" => "default.typst",
        "outputFormat" => "pdf"
      }
    }

    assert {:error, _} = WraftJson.validate_json(missing_name)
  end
end
