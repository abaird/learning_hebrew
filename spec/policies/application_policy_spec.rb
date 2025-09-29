require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  let(:superuser) { User.create!(email: "super_#{rand(10000)}@example.com", password: 'password123', superuser: true) }
  let(:regular_user) { User.create!(email: "regular_#{rand(10000)}@example.com", password: 'password123') }
  let(:record) { double('record') }

  after(:each) do
    User.destroy_all
  end

  describe '#index?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, record).index?).to be true
      expect(described_class.new(superuser, record).index?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, record).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, record).show?).to be true
      expect(described_class.new(superuser, record).show?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, record).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, record).create?).to be true
      expect(described_class.new(regular_user, record).create?).to be false
      expect(described_class.new(nil, record).create?).to be false
    end
  end

  describe '#new?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, record).new?).to be true
      expect(described_class.new(regular_user, record).new?).to be false
      expect(described_class.new(nil, record).new?).to be false
    end
  end

  describe '#update?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, record).update?).to be true
      expect(described_class.new(regular_user, record).update?).to be false
      expect(described_class.new(nil, record).update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, record).edit?).to be true
      expect(described_class.new(regular_user, record).edit?).to be false
      expect(described_class.new(nil, record).edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, record).destroy?).to be true
      expect(described_class.new(regular_user, record).destroy?).to be false
      expect(described_class.new(nil, record).destroy?).to be false
    end
  end
end
