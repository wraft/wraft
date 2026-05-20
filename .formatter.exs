[
  inputs: ["mix.exs", "{config,lib,test,priv}/**/*.{ex,exs}"],
  import_deps: [:open_api_spex, :backpex, :phoenix],
  locals_without_parens: [plug: 1, plug: 2]
]
