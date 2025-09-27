class HealthController < ApplicationController
  # Skip authentication for health checks
  # Note: No authentication required for health endpoints

  def show
    # Basic health check
    Rails.application.executor.wrap do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end

    build_info = {
      status: "ok",
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      database: {
        adapter: ActiveRecord::Base.connection.adapter_name,
        connected: ActiveRecord::Base.connected?
      },
      deployment: {
        git_sha: ENV["GIT_SHA"] || ENV["GITHUB_SHA"] || "unknown",
        build_number: ENV["BUILD_NUMBER"] || ENV["GITHUB_RUN_NUMBER"] || "unknown",
        deployed_at: ENV["DEPLOYED_AT"] || "unknown",
        image_tag: ENV["IMAGE_TAG"] || "unknown"
      }
    }

    respond_to do |format|
      format.json { render json: build_info }
      format.html { render json: build_info, layout: false }
      format.any { render json: build_info }
    end
  rescue => e
    error_info = {
      status: "error",
      timestamp: Time.current.iso8601,
      error: e.message,
      environment: Rails.env
    }

    respond_to do |format|
      format.json { render json: error_info, status: :service_unavailable }
      format.html { render json: error_info, status: :service_unavailable, layout: false }
      format.any { render json: error_info, status: :service_unavailable }
    end
  end
end
