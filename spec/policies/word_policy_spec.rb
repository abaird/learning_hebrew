require 'rails_helper'

RSpec.describe WordPolicy, type: :policy do
  let(:superuser) { User.create!(email: "super_#{rand(10000)}@example.com", password: 'password123', superuser: true) }
  let(:regular_user) { User.create!(email: "regular_#{rand(10000)}@example.com", password: 'password123') }
  let(:word) { Word.create!(representation: 'שלום') }

  after(:each) do
    User.destroy_all
    Word.destroy_all
  end

  describe '#index?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, word).index?).to be true
      expect(described_class.new(superuser, word).index?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, word).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, word).show?).to be true
      expect(described_class.new(superuser, word).show?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, word).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, word).create?).to be true
      expect(described_class.new(regular_user, word).create?).to be false
      expect(described_class.new(nil, word).create?).to be false
    end
  end

  describe '#new?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, word).new?).to be true
      expect(described_class.new(regular_user, word).new?).to be false
      expect(described_class.new(nil, word).new?).to be false
    end
  end

  describe '#update?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, word).update?).to be true
      expect(described_class.new(regular_user, word).update?).to be false
      expect(described_class.new(nil, word).update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, word).edit?).to be true
      expect(described_class.new(regular_user, word).edit?).to be false
      expect(described_class.new(nil, word).edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, word).destroy?).to be true
      expect(described_class.new(regular_user, word).destroy?).to be false
      expect(described_class.new(nil, word).destroy?).to be false
    end
  end
end
