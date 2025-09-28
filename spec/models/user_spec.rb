require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:decks).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
  end

  describe 'superuser functionality' do
    let(:regular_user) { User.create!(email: 'user@example.com', password: 'password123') }
    let(:super_user) { User.create!(email: 'admin@example.com', password: 'password123', superuser: true) }

    describe '#superuser?' do
      it 'returns false for regular users' do
        expect(regular_user.superuser?).to be false
      end

      it 'returns true for superusers' do
        expect(super_user.superuser?).to be true
      end

      it 'returns false when superuser is nil' do
        user = User.create!(email: 'test@example.com', password: 'password123')
        expect(user.superuser?).to be false
      end
    end
  end
end