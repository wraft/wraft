defmodule WraftDoc.Workers.DefaultWorker do
  @moduledoc """
  Default Oban worker for all trivial jobs.
  """
  use Oban.Worker, queue: :default

  import Ecto.Query

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Document
  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.DataTemplate
  alias WraftDoc.Document.Engine
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.LayoutAsset
  alias WraftDoc.Document.Theme
  alias WraftDoc.Document.ThemeAsset
  alias WraftDoc.Repo

  @superadmin_role "superadmin"

  @theme_folder_path Application.compile_env!(:wraft_doc, [:theme_folder])

  @wraft_theme_args %{
    name: "Wraft Frame",
    font: "Roboto ",
    body_color: "#111",
    primary_color: "#000",
    secondary_color: "#333"
  }

  @layout_file_path Application.compile_env!(:wraft_doc, [:layout_file])

  @wraft_layout_args %{
    name: "Wraft Layout",
    description: "Wraft Layout",
    slug: "pletter",
    height: "40",
    width: "40",
    unit: "cm"
  }

  @wraft_layout_asset_args %{
    name: @wraft_layout_args.name,
    type: "layout",
    file: %Plug.Upload{
      filename: "letterhead.pdf",
      content_type: "application/pdf"
    }
  }

  @content_type_params_1 %{
    "name" => "Wraft Offer Letter",
    "description" => "Variant to create Offer Letter with few variable fields",
    "prefix" => "WLV",
    "color" => "#595e01",
    "fields" => [
      %{
        "type" => "string",
        "name" => "clientName"
      },
      %{
        "type" => "string",
        "name" => "paymentSchedule"
      },
      %{
        "type" => "string",
        "name" => "ourName"
      },
      %{
        "type" => "date",
        "name" => "date"
      }
    ]
  }

  @content_type_params_2 %{
    "name" => "Mutual NDA",
    "prefix" => "MNDA",
    "color" => "#b8b3de",
    "description" =>
      "Mutual Non-Disclosure Agreement with few variables which user can dynamically change according to the context\n\nreferenced from:  https://github.com/CommonPaper/Mutual-NDA",
    "fields" => [
      %{
        "type" => "date",
        "name" => "Effective Date"
      },
      %{
        "type" => "text",
        "name" => "MNDA Term"
      },
      %{
        "type" => "text",
        "name" => "Term of Confidentiality"
      },
      %{
        "type" => "text",
        "name" => "Governing Law"
      },
      %{
        "type" => "text",
        "name" => "Jurisdiction"
      }
    ]
  }

  @data_template_params_1 %{
    title: "Wraft Offer Letter Template",
    title_template: "Offer Letter for [Employee_Name]",
    data:
      "Dear Employee\\_Name ,\n\nCongratulations! We are pleased to confirm that you have been selected to work for Company\\_Name . We are delighted to\n\nmake you the following job offer:\n\nThe position we are offering you is that of Job\\_Title with an annual cost to company of 330000. This position reports\n\nto Manager\\_Name .\n\nWe would like you to start work on Employee\\_Joining\\_Date. Please report to Manager\\_Name for documentation and\n\norientation. If this date is not acceptable, please contact me immediately. On joining, you will be invited to our HR tool (XPayroll)\n\nin which you may be required to upload your documents.\n\nPlease sign the enclosed copy of this letter and return it to me by Acceptance\\_Last\\_Date to indicate your acceptance of this\n\noffer.\n\nWe are confident you will be able to make a significant contribution to the success of Company\\_Name and look forward to\n\nworking with you.\n\nSincerely,\n\nHR\\_Name\n\nCompany\\_Name\n\nAccepted by,\n\nEmployee\\_Name",
    serialized: %{
      "data" =>
        Jason.encode!(%{
          "content" => [
            %{
              "content" => [
                %{"text" => "Dear ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "f1dbc793-4475-4618-aa9b-658c7264006a",
                    "label" => "Employee_Name",
                    "mentionTag" => "holder",
                    "name" => "Employee_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " ,", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "Congratulations! We are pleased to confirm that you have been selected to work for ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "a1afa979-a7de-4ed9-a66f-119c8e3371b6",
                    "label" => "Company_Name",
                    "mentionTag" => "holder",
                    "name" => "Company_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " . We are delighted to", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{"text" => "make you the following job offer:", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" => "The position we are offering you is that of ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "73b233ac-523f-421b-941d-111c869f5cc7",
                    "label" => "Job_Title",
                    "mentionTag" => "holder",
                    "name" => "Job_Title",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{
                  "text" => "  with an annual cost to company of 330000. This position reports",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{"text" => "to ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "e7d20679-458d-413b-80fe-aecfca502a91",
                    "label" => "Manager_Name",
                    "mentionTag" => "holder",
                    "name" => "Manager_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " .", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{"text" => "We would like you to start work on ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "ad028a51-1703-40fe-8701-e84e6a3eb846",
                    "label" => "Employee_Joining_Date",
                    "mentionTag" => "holder",
                    "name" => "Employee_Joining_Date",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => ". Please report to ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "e7d20679-458d-413b-80fe-aecfca502a91",
                    "label" => "Manager_Name",
                    "mentionTag" => "holder",
                    "name" => "Manager_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => "  for documentation and", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "orientation. If this date is not acceptable, please contact me immediately. On joining, you will be invited to our HR tool (XPayroll)",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" => "in which you may be required to upload your documents.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "Please sign the enclosed copy of this letter and return it to me by ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "bae27fdf-a651-4e73-8411-93431a3a871d",
                    "label" => "Acceptance_Last_Date",
                    "mentionTag" => "holder",
                    "name" => "Acceptance_Last_Date",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => "  to indicate your acceptance of this", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [%{"text" => "offer.", "type" => "text"}],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "We are confident you will be able to make a significant contribution to the success of ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "a1afa979-a7de-4ed9-a66f-119c8e3371b6",
                    "label" => "Company_Name",
                    "mentionTag" => "holder",
                    "name" => "Company_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => "  and look forward to", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [%{"text" => "working with you.", "type" => "text"}],
              "type" => "paragraph"
            },
            %{
              "content" => [%{"text" => "Sincerely,", "type" => "text"}],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "attrs" => %{
                    "id" => "9c6e6d51-2968-4146-a028-9b9d5776df05",
                    "label" => "HR_Name",
                    "mentionTag" => "holder",
                    "name" => "HR_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " ", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "attrs" => %{
                    "id" => "a1afa979-a7de-4ed9-a66f-119c8e3371b6",
                    "label" => "Company_Name",
                    "mentionTag" => "holder",
                    "name" => "Company_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " ", "type" => "text"}
              ],
              "type" => "paragraph"
            },
            %{
              "content" => [%{"text" => "Accepted by,", "type" => "text"}],
              "type" => "paragraph"
            },
            %{
              "content" => [
                %{
                  "attrs" => %{
                    "id" => "f1dbc793-4475-4618-aa9b-658c7264006a",
                    "label" => "Employee_Name",
                    "mentionTag" => "holder",
                    "name" => "Employee_Name",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => " ", "type" => "text"}
              ],
              "type" => "paragraph"
            }
          ],
          "type" => "doc"
        })
    }
  }

  @data_template_params_2 %{
    title: "Wraft Mutual NDA Template",
    title_template: "Mutual Non-Disclosure Agreement",
    data:
      "# **Introduction**\n\nThis Mutual Non-Disclosure Agreement (which incorporates these Standard Terms and the Cover Page (defined below)) (“MNDA”) allows each party (“Disclosing Party”) to disclose or make available information in connection with the Purpose which (1) the Disclosing Party identifies to the receiving party (“Receiving Party”) as “confidential”, “proprietary”, or the like or (2) should be reasonably understood as confidential or proprietary due to its nature and the circumstances of its disclosure (“Confidential Information”). Each party’s Confidential Information also includes the existence and status of the parties’ discussions and information on the Cover Page. Confidential Information includes technical or business information, product designs or roadmaps, requirements, pricing, security and compliance documentation, technology, inventions and know-how. To use this MNDA, the parties must complete and sign a cover page incorporating these Standard Terms (“Cover Page”). Each party is identified on the Cover Page and capitalized terms have the meanings given herein or on the Cover Page.\n\n# **Use and Protection of Confidential Information**\n\nThe Receiving Party shall: (a) use Confidential Information solely for the Purpose; (b) not disclose Confidential Information to third parties without the Disclosing Party’s prior written approval, except that the Receiving Party may disclose Confidential Information to its employees, agents, advisors, contractors, and other representatives having a reasonable need to know for the Purpose, provided these representatives are bound by confidentiality obligations no less protective of the Disclosing Party than the applicable terms in this MNDA and the Receiving Party remains responsible for their compliance with this MNDA; and (c) protect Confidential Information using at least the same protections the Receiving Party uses for its own similar information but no less than a reasonable standard of care.\n\n# **Exceptions**\n\nThe Receiving Party’s obligations in this MNDA do not apply to information that it can demonstrate: (a) is or becomes publicly available through no fault of the Receiving Party; (b) it rightfully knew or possessed prior to receipt from the Disclosing Party without confidentiality restrictions; (c) it rightfully obtained from a third party without confidentiality restrictions; or (d) it independently developed without using or referencing the Confidential Information.\n\n# **Disclosures Required by Law**\n\nThe Receiving Party may disclose Confidential Information to the extent required by law, regulation, or regulatory authority, subpoena or court order, provided (to the extent legally permitted) it provides the Disclosing Party reasonable advance notice of the required disclosure and reasonably cooperates, at the Disclosing Party’s expense, with the Disclosing Party’s efforts to obtain confidential treatment for the Confidential Information.\n\n# **Term and Termination**\n\nThis MNDA commences on the Effective Date Date and expires at the end of the MNDA Term Term. Either party may terminate this MNDA for any or no reason upon written notice to the other party. The Receiving Party’s obligations relating to Confidential Information will survive for the Term of Confidentiality of Confidentiality, despite any expiration or termination of this MNDA.\n\n# **Return or Destruction of Confidential Information**\n\nUpon expiration or termination of this MNDA or upon the Disclosing Party’s earlier request, the Receiving Party will: (a) cease using Confidential Information; (b) promptly after the Disclosing Party’s written request, destroy all Confidential Information in the Receiving Party’s possession or control or return it to the Disclosing Party; and (c) if requested by the Disclosing Party, confirm its compliance with these obligations in writing. As an exception to subsection (b), the Receiving Party may retain Confidential Information in accordance with its standard backup or record retention policies or as required by law, but the terms of this MNDA will continue to apply to the retained Confidential Information.\n\n# **Proprietary Rights**\n\nThe Disclosing Party retains all of its intellectual property and other rights in its Confidential Information and its disclosure to the Receiving Party grants no license under such rights.\n\n# **Disclaimer**\n\nALL CONFIDENTIAL INFORMATION IS PROVIDED “AS IS”, WITH ALL FAULTS, AND WITHOUT WARRANTIES, INCLUDING THE IMPLIED WARRANTIES OF TITLE, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.\n\n# **Governing Law and Jurisdiction**\n\nThis MNDA and all matters relating hereto are governed by, and construed in accordance with, the laws of the State of Governing Law Law, without regard to the conflict of laws provisions of such Governing Law. Any legal suit, action, or proceeding relating to this MNDA must be instituted in the federal or state courts located in Jurisdiction . Each party irrevocably submits to the exclusive jurisdiction of such Jurisdiction in any such suit, action, or proceeding.\n\n# **Equitable Relief**\n\nA breach of this MNDA may cause irreparable harm for which monetary damages are an insufficient remedy. Upon a breach of this MNDA, the Disclosing Party is entitled to seek appropriate equitable relief, including an injunction, in addition to its other remedies.\n\n# **General**\n\nNeither party has an obligation under this MNDA to disclose Confidential Information to the other or proceed with any proposed transaction. Neither party may assign this MNDA without the prior written consent of the other party, except that either party may assign this MNDA in connection with a merger, reorganization, acquisition, or other transfer of all or substantially all its assets or voting securities. Any assignment in violation of this Section is null and void. This MNDA will bind and inure to the benefit of each party’s permitted successors and assigns. Waivers must be signed by the waiving party’s authorized representative and cannot be implied from conduct. If any provision of this MNDA is held unenforceable, it will be limited to the minimum extent necessary so the rest of this MNDA remains in effect. This MNDA (including the Cover Page) constitutes the entire agreement of the parties with respect to its subject matter, and supersedes all prior and contemporaneous understandings, agreements, representations, and warranties, whether written or oral, regarding such subject matter. This MNDA may only be amended, modified, waived, or supplemented by an agreement in writing signed by both parties. Notices, requests, and approvals under this MNDA must be sent in writing to the email or postal addresses on the Cover Page and are deemed delivered on receipt. This MNDA may be executed in counterparts, including electronic copies, each of which is deemed an original and which together form the same agreement.",
    serialized: %{
      "data" =>
        Jason.encode!(%{
          "content" => [
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Introduction",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "This Mutual Non-Disclosure Agreement (which incorporates these Standard Terms and the Cover Page (defined below)) (“MNDA”) allows each party (“Disclosing Party”) to disclose or make available information in connection with the Purpose which (1) the Disclosing Party identifies to the receiving party (“Receiving Party”) as “confidential”, “proprietary”, or the like or (2) should be reasonably understood as confidential or proprietary due to its nature and the circumstances of its disclosure (“Confidential Information”). Each party’s Confidential Information also includes the existence and status of the parties’ discussions and information on the Cover Page. Confidential Information includes technical or business information, product designs or roadmaps, requirements, pricing, security and compliance documentation, technology, inventions and know-how. To use this MNDA, the parties must complete and sign a cover page incorporating these Standard Terms (“Cover Page”). Each party is identified on the Cover Page and capitalized terms have the meanings given herein or on the Cover Page.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Use and Protection of Confidential Information",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "The Receiving Party shall: (a) use Confidential Information solely for the Purpose; (b) not disclose Confidential Information to third parties without the Disclosing Party’s prior written approval, except that the Receiving Party may disclose Confidential Information to its employees, agents, advisors, contractors, and other representatives having a reasonable need to know for the Purpose, provided these representatives are bound by confidentiality obligations no less protective of the Disclosing Party than the applicable terms in this MNDA and the Receiving Party remains responsible for their compliance with this MNDA; and (c) protect Confidential Information using at least the same protections the Receiving Party uses for its own similar information but no less than a reasonable standard of care.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Exceptions",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "The Receiving Party’s obligations in this MNDA do not apply to information that it can demonstrate: (a) is or becomes publicly available through no fault of the Receiving Party; (b) it rightfully knew or possessed prior to receipt from the Disclosing Party without confidentiality restrictions; (c) it rightfully obtained from a third party without confidentiality restrictions; or (d) it independently developed without using or referencing the Confidential Information.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Disclosures Required by Law",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "The Receiving Party may disclose Confidential Information to the extent required by law, regulation, or regulatory authority, subpoena or court order, provided (to the extent legally permitted) it provides the Disclosing Party reasonable advance notice of the required disclosure and reasonably cooperates, at the Disclosing Party’s expense, with the Disclosing Party’s efforts to obtain confidential treatment for the Confidential Information.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Term and Termination",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{"text" => "This MNDA commences on the ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "d1245e13-44a8-45f3-9c1d-8483cf6f94cf",
                    "label" => "Effective Date",
                    "mentionTag" => "holder",
                    "name" => "Effective Date",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{"text" => "  Date and expires at the end of the ", "type" => "text"},
                %{
                  "attrs" => %{
                    "id" => "6a54a9d0-874a-4ea3-be13-6a29c2146aa1",
                    "label" => "MNDA Term",
                    "mentionTag" => "holder",
                    "name" => "MNDA Term",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{
                  "text" =>
                    "  Term. Either party may terminate this MNDA for any or no reason upon written notice to the other party. The Receiving Party’s obligations relating to Confidential Information will survive for the ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "14d61427-74ff-4205-9e6b-a41f9cc91f22",
                    "label" => "Term of Confidentiality",
                    "mentionTag" => "holder",
                    "name" => "Term of Confidentiality",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{
                  "text" =>
                    "  of Confidentiality, despite any expiration or termination of this MNDA.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Return or Destruction of Confidential Information",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "Upon expiration or termination of this MNDA or upon the Disclosing Party’s earlier request, the Receiving Party will: (a) cease using Confidential Information; (b) promptly after the Disclosing Party’s written request, destroy all Confidential Information in the Receiving Party’s possession or control or return it to the Disclosing Party; and (c) if requested by the Disclosing Party, confirm its compliance with these obligations in writing. As an exception to subsection (b), the Receiving Party may retain Confidential Information in accordance with its standard backup or record retention policies or as required by law, but the terms of this MNDA will continue to apply to the retained Confidential Information.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Proprietary Rights",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "The Disclosing Party retains all of its intellectual property and other rights in its Confidential Information and its disclosure to the Receiving Party grants no license under such rights.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Disclaimer",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "ALL CONFIDENTIAL INFORMATION IS PROVIDED “AS IS”, WITH ALL FAULTS, AND WITHOUT WARRANTIES, INCLUDING THE IMPLIED WARRANTIES OF TITLE, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Governing Law and Jurisdiction",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "This MNDA and all matters relating hereto are governed by, and construed in accordance with, the laws of the State of ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "6706f77a-55ce-47ea-8ba9-db852bacf37a",
                    "label" => "Governing Law",
                    "mentionTag" => "holder",
                    "name" => "Governing Law",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{
                  "text" =>
                    "  Law, without regard to the conflict of laws provisions of such Governing Law. Any legal suit, action, or proceeding relating to this MNDA must be instituted in the federal or state courts located in ",
                  "type" => "text"
                },
                %{
                  "attrs" => %{
                    "id" => "90dcd1de-39a9-48e2-9ca5-9816cfabfa35",
                    "label" => "Jurisdiction",
                    "mentionTag" => "holder",
                    "name" => "Jurisdiction",
                    "named" => ""
                  },
                  "type" => "holder"
                },
                %{
                  "text" =>
                    " . Each party irrevocably submits to the exclusive jurisdiction of such Jurisdiction in any such suit, action, or proceeding.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "Equitable Relief",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "A breach of this MNDA may cause irreparable harm for which monetary damages are an insufficient remedy. Upon a breach of this MNDA, the Disclosing Party is entitled to seek appropriate equitable relief, including an injunction, in addition to its other remedies.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            },
            %{
              "attrs" => %{"level" => 1},
              "content" => [
                %{
                  "marks" => [%{"type" => "bold"}],
                  "text" => "General",
                  "type" => "text"
                }
              ],
              "type" => "heading"
            },
            %{
              "content" => [
                %{
                  "text" =>
                    "Neither party has an obligation under this MNDA to disclose Confidential Information to the other or proceed with any proposed transaction. Neither party may assign this MNDA without the prior written consent of the other party, except that either party may assign this MNDA in connection with a merger, reorganization, acquisition, or other transfer of all or substantially all its assets or voting securities. Any assignment in violation of this Section is null and void. This MNDA will bind and inure to the benefit of each party’s permitted successors and assigns. Waivers must be signed by the waiving party’s authorized representative and cannot be implied from conduct. If any provision of this MNDA is held unenforceable, it will be limited to the minimum extent necessary so the rest of this MNDA remains in effect. This MNDA (including the Cover Page) constitutes the entire agreement of the parties with respect to its subject matter, and supersedes all prior and contemporaneous understandings, agreements, representations, and warranties, whether written or oral, regarding such subject matter. This MNDA may only be amended, modified, waived, or supplemented by an agreement in writing signed by both parties. Notices, requests, and approvals under this MNDA must be sent in writing to the email or postal addresses on the Cover Page and are deemed delivered on receipt. This MNDA may be executed in counterparts, including electronic copies, each of which is deemed an original and which together form the same agreement.",
                  "type" => "text"
                }
              ],
              "type" => "paragraph"
            }
          ],
          "type" => "doc"
        })
    }
  }

  @impl Oban.Worker
  def perform(%Job{
        args: %{"organisation_id" => organisation_id, "user_id" => user_id},
        tags: ["personal_organisation_roles"]
      }) do
    Multi.new()
    |> Multi.insert(:role, %Role{name: @superadmin_role, organisation_id: organisation_id})
    |> Multi.insert(:user_role, fn %{role: role} ->
      %UserRole{role_id: role.id, user_id: user_id}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Personal Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  # TODO Need to consider about the layout having pletter slug and h1 tags in md.
  def perform(%Job{tags: ["wraft_templates"]} = job) do
    organisation_id = job.args["organisation_id"]
    flow_id = job.args["flow_id"]
    current_user_id = job.args["current_user_id"]

    current_user =
      User
      |> Repo.get(current_user_id)
      |> Map.put(:current_org_id, organisation_id)

    %{id: engine_id} = Repo.get_by(Engine, name: "Pandoc")

    Multi.new()
    |> Multi.insert(
      :theme,
      Theme.changeset(%Theme{}, Map.put(@wraft_theme_args, :organisation_id, organisation_id))
    )
    |> Multi.insert(
      :layout,
      Layout.changeset(
        %Layout{},
        Map.merge(@wraft_layout_args, %{organisation_id: organisation_id, engine_id: engine_id})
      )
    )
    |> Multi.insert(
      :contract_layout,
      Layout.changeset(
        %Layout{},
        Map.merge(@wraft_layout_args, %{
          name: "Wraft Contract Layout",
          organisation_id: organisation_id,
          engine_id: engine_id,
          slug: "contract"
        })
      )
    )
    |> Multi.run(:upload_layout_asset, fn _, %{layout: layout} ->
      create_wraft_layout_assets(layout, organisation_id)
    end)
    |> Multi.run(:upload_theme_asset, fn _, %{theme: theme} ->
      create_wraft_theme_assets(theme, organisation_id)
    end)
    |> Multi.run(:content_type_1, fn _, %{theme: theme, layout: layout} ->
      create_wraft_variant(current_user, theme, layout, flow_id, @content_type_params_1)
    end)
    |> Multi.insert(:data_template_1, fn %{content_type_1: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(@data_template_params_1, %{
          content_type_id: content_type.id,
          creator_id: current_user_id
        })
      )
    end)
    |> Multi.run(:content_type_2, fn _, %{theme: theme, contract_layout: layout} ->
      create_wraft_variant(current_user, theme, layout, flow_id, @content_type_params_2)
    end)
    |> Multi.insert(:data_template_2, fn %{content_type_2: content_type} ->
      DataTemplate.changeset(
        %DataTemplate{},
        Map.merge(@data_template_params_2, %{
          content_type_id: content_type.id,
          creator_id: current_user_id
        })
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Wraft theme and layout creation failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{args: %{"user_id" => user_id, "roles" => role_ids}, tags: ["assign_role"]}) do
    Enum.each(role_ids, &Account.create_user_role(user_id, &1))
    :ok
  end

  # Creates a wraft branded asset, uploads the file and returns the id.
  defp create_wraft_branded_asset(organisation_id, params) do
    %Asset{}
    |> Asset.changeset(Map.put(params, :organisation_id, organisation_id))
    |> Repo.insert!()
    |> Asset.file_changeset(params)
    |> Repo.update!()
    |> Map.get(:id)
  end

  defp create_wraft_theme_assets(theme, organisation_id) do
    font_files =
      @theme_folder_path
      |> File.ls!()
      |> Enum.filter(fn file -> String.ends_with?(file, ".ttf") end)

    Enum.each(font_files, fn font_file ->
      asset_params = %{
        name: Path.basename(font_file),
        type: "theme",
        file: %Plug.Upload{
          filename: Path.basename(font_file),
          path: Path.join(@theme_folder_path, font_file),
          content_type: "application/octet-stream"
        }
      }

      asset_id = create_wraft_branded_asset(organisation_id, asset_params)
      Repo.insert(%ThemeAsset{theme_id: theme.id, asset_id: asset_id})
    end)

    {:ok, "ok"}
  end

  defp create_wraft_layout_assets(layout, organisation_id) do
    asset_params =
      Map.update!(@wraft_layout_asset_args, :file, fn upload ->
        %Plug.Upload{upload | path: @layout_file_path}
      end)

    asset_id = create_wraft_branded_asset(organisation_id, asset_params)
    Repo.insert(%LayoutAsset{layout_id: layout.id, asset_id: asset_id})

    {:ok, "ok"}
  end

  defp create_wraft_variant(current_user, theme, layout, flow_id, params) do
    with params <-
           create_wraft_variant_params(current_user.id, params, theme.id, layout.id, flow_id),
         %ContentType{} = content_type <- Document.create_content_type(current_user, params) do
      {:ok, content_type}
    end
  end

  defp create_wraft_variant_params(current_user_id, params, theme_id, layout_id, flow_id) do
    field_types = Repo.all(from(ft in FieldType, select: {ft.name, ft.id}))
    field_type_map = Map.new(field_types)

    fields =
      Enum.map(params["fields"], fn field ->
        field_type = String.capitalize(field["type"])

        %{
          "field_type_id" => Map.get(field_type_map, field_type),
          "key" => field["name"],
          "name" => field["name"]
        }
      end)

    Map.merge(params, %{
      "theme_id" => theme_id,
      "layout_id" => layout_id,
      "flow_id" => flow_id,
      "creator_id" => current_user_id,
      "fields" => fields
    })
  end
end
