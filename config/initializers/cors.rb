# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      /localhost:\d{2,4}/,
      /glancr.conf:\d{2,4}/,
      /\d{3}.\d{3}.\d{1,3}.\d{1,3}:\d{2,4}/, # local network access
      /[\w-]+.local:\d{2,4}/ # local network via bonjour / zeroconf
    )

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end
