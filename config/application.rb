require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PushIt
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Berlin"
    config.i18n.default_locale = :de
    config.i18n.available_locales = %i[de en]

    # Accounts stay hidden until mail delivery works; registration and sign-in remain reachable by URL.
    config.x.accounts_visible = ENV["ACCOUNTS_VISIBLE"] == "true"
    # config.eager_load_paths << Rails.root.join("extras")

    # Native apps open the cable without an Origin header. Browsers always send one, so
    # they still have to come from the same host; apps then identify by guest token.
    config.action_cable.allowed_request_origins = [ ->(origin) { origin.nil? } ]
  end
end
