import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :forhu, ForhuWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "W9omXQ54BbF5sIR7KYEUeEk8FN118Q3aVIKJOVVcVjg/5zbzJ5ZXSj1JKugSTD9B",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
