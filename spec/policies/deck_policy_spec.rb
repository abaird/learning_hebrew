require 'rails_helper'

RSpec.describe DeckPolicy, type: :policy do
  let(:superuser) { User.create!(email: "super_#{rand(10000)}@example.com", password: 'password123', superuser: true) }
  let(:regular_user) { User.create!(email: "regular_#{rand(10000)}@example.com", password: 'password123') }
  let(:other_user) { User.create!(email: "other_#{rand(10000)}@example.com", password: 'password123') }
  let(:user_deck) { Deck.create!(name: 'User Deck', user: regular_user) }
  let(:other_deck) { Deck.create!(name: 'Other Deck', user: other_user) }

  after(:each) do
    User.destroy_all
    Deck.destroy_all
  end

  describe '#index?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, user_deck).index?).to be true
      expect(described_class.new(superuser, user_deck).index?).to be true
      expect(described_class.new(other_user, user_deck).index?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, user_deck).show?).to be true
      expect(described_class.new(superuser, user_deck).show?).to be true
      expect(described_class.new(other_user, user_deck).show?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, user_deck).create?).to be true
      expect(described_class.new(superuser, user_deck).create?).to be true
      expect(described_class.new(other_user, user_deck).create?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).create?).to be false
    end
  end

  describe '#new?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, user_deck).new?).to be true
      expect(described_class.new(superuser, user_deck).new?).to be true
      expect(described_class.new(other_user, user_deck).new?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).new?).to be false
    end
  end

  describe '#update?' do
    it 'allows access for deck owner' do
      expect(described_class.new(regular_user, user_deck).update?).to be true
    end

    it 'allows access for superuser regardless of ownership' do
      expect(described_class.new(superuser, user_deck).update?).to be true
      expect(described_class.new(superuser, other_deck).update?).to be true
    end

    it 'denies access for non-owners who are not superuser' do
      expect(described_class.new(other_user, user_deck).update?).to be false
      expect(described_class.new(regular_user, other_deck).update?).to be false
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows access for deck owner' do
      expect(described_class.new(regular_user, user_deck).edit?).to be true
    end

    it 'allows access for superuser regardless of ownership' do
      expect(described_class.new(superuser, user_deck).edit?).to be true
      expect(described_class.new(superuser, other_deck).edit?).to be true
    end

    it 'denies access for non-owners who are not superuser' do
      expect(described_class.new(other_user, user_deck).edit?).to be false
      expect(described_class.new(regular_user, other_deck).edit?).to be false
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows access for deck owner' do
      expect(described_class.new(regular_user, user_deck).destroy?).to be true
    end

    it 'allows access for superuser regardless of ownership' do
      expect(described_class.new(superuser, user_deck).destroy?).to be true
      expect(described_class.new(superuser, other_deck).destroy?).to be true
    end

    it 'denies access for non-owners who are not superuser' do
      expect(described_class.new(other_user, user_deck).destroy?).to be false
      expect(described_class.new(regular_user, other_deck).destroy?).to be false
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, user_deck).destroy?).to be false
    end
  end
end
