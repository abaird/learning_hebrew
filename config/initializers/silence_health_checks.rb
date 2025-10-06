# Simple middleware to silence specific paths
module Rack
  class SilenceRequest
    def initialize(app, *paths)
      @app = app
      @paths = paths
    end

    def call(env)
      if @paths.any? { |path| env["PATH_INFO"].start_with?(path) }
        Rails.logger.silence { @app.call(env) }
      else
        @app.call(env)
      end
    end
  end
end

# Silence logs for health check requests to reduce noise
Rails.application.config.middleware.insert_before(
  Rails::Rack::Logger,
  Rack::SilenceRequest,
  "/up"
)
