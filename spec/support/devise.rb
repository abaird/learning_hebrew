# Devise test helpers for RSpec
require 'devise'

RSpec.configure do |config|
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature

  # Helper method to sign in a user for tests
  def sign_in_test_user
    user = users(:test_user)
    sign_in user
    user
  end

  # Helper method to create and sign in a user
  def create_and_sign_in_user(attributes = {})
    user_attributes = {
      email: "test#{rand(1000)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(attributes)

    user = User.create!(user_attributes)
    sign_in user
    user
  end
end
