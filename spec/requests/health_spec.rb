require 'rails_helper'

RSpec.describe "/up", type: :request do
  describe "GET /up" do
    it "returns health status without authentication" do
      # This test ensures the health endpoint works without authentication
      # Critical for Kubernetes readiness/liveness probes
      get "/up"
      expect(response).to be_successful
      expect(response.content_type).to match(a_string_including("application/json"))
    end

    it "includes required health information" do
      get "/up"

      json_response = JSON.parse(response.body)

      expect(json_response).to include(
        "status" => "ok",
        "timestamp" => be_present,
        "environment" => Rails.env,
        "rails_version" => Rails.version,
        "ruby_version" => RUBY_VERSION
      )

      expect(json_response["database"]).to include(
        "adapter" => "PostgreSQL",
        "connected" => true
      )

      expect(json_response["deployment"]).to include(
        "git_sha" => be_present,
        "build_number" => be_present,
        "deployed_at" => be_present,
        "image_tag" => be_present
      )
    end

    it "works when database is connected" do
      get "/up"

      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("ok")
      expect(json_response["database"]["connected"]).to be true
    end

    it "handles database errors gracefully" do
      # Mock a database error to test error handling
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError.new("Database unavailable"))

      get "/up"

      expect(response).to have_http_status(:service_unavailable)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("error")
      expect(json_response["error"]).to include("Database unavailable")
    end

    it "responds to different formats" do
      # Test JSON format (default)
      get "/up", headers: { "Accept" => "application/json" }
      expect(response).to be_successful
      expect(response.content_type).to match(a_string_including("application/json"))

      # Test HTML format (should still return JSON but work)
      get "/up", headers: { "Accept" => "text/html" }
      expect(response).to be_successful
      expect(response.body).to include('"status":"ok"')

      # Test any other format
      get "/up", headers: { "Accept" => "text/plain" }
      expect(response).to be_successful
      expect(response.body).to include('"status":"ok"')
    end

    context "when authentication is required for other endpoints" do
      it "bypasses authentication for health checks" do
        # Ensure that even with global authentication, health endpoint works
        # This is critical - if this test fails, Kubernetes probes will fail

        # Verify authentication is actually enabled by testing another endpoint
        get "/words"
        expect(response).to have_http_status(:found) # Should redirect to login
        expect(response.location).to include("/users/sign_in")

        # But health endpoint should still work
        get "/up"
        expect(response).to be_successful
        expect(response).not_to have_http_status(:found) # Should NOT redirect
      end
    end
  end
end
