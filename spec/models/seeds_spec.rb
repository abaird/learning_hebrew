require 'rails_helper'

RSpec.describe "Database Seeds", type: :model do
  before(:each) do
    User.destroy_all
  end

  describe "seed creation" do
    it "creates a superuser with the correct email in development" do
      allow(Rails.env).to receive(:production?).and_return(false)

      expect {
        load Rails.root.join("db/seeds.rb")
      }.to change(User, :count).by(1)

      superuser = User.find_by(email: 'abaird@bairdsnet.net')
      expect(superuser).to be_present
      expect(superuser.superuser?).to be true
    end

    it "does not create duplicate superusers when run multiple times" do
      allow(Rails.env).to receive(:production?).and_return(false)

      # Run seeds twice
      load Rails.root.join("db/seeds.rb")
      expect {
        load Rails.root.join("db/seeds.rb")
      }.not_to change(User, :count)

      expect(User.where(email: 'abaird@bairdsnet.net').count).to eq(1)
    end

    it "uses environment variable password in production" do
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).with('SUPERUSER_PASSWORD').and_return('production_password')

      load Rails.root.join("db/seeds.rb")

      superuser = User.find_by(email: 'abaird@bairdsnet.net')
      expect(superuser.valid_password?('production_password')).to be true
    end

    it "uses default password in non-production environments" do
      allow(Rails.env).to receive(:production?).and_return(false)

      load Rails.root.join("db/seeds.rb")

      superuser = User.find_by(email: 'abaird@bairdsnet.net')
      expect(superuser.valid_password?('secret!')).to be true
    end
  end
end
