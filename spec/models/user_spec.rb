require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:decks).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
  end

  describe 'superuser functionality' do
    after(:each) do
      User.destroy_all
    end

    describe '#superuser?' do
      it 'returns false for regular users' do
        user = User.create!(email: "regular_#{rand(10000)}@example.com", password: 'password123')
        expect(user.superuser?).to be false
      end

      it 'returns true for superusers' do
        user = User.create!(email: "super_#{rand(10000)}@example.com", password: 'password123', superuser: true)
        expect(user.superuser?).to be true
      end

      it 'returns false when superuser is nil' do
        user = User.create!(email: "nil_test_#{rand(10000)}@example.com", password: 'password123')
        expect(user.superuser?).to be false
      end
    end
  end
end
