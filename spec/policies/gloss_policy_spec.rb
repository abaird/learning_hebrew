require 'rails_helper'

RSpec.describe GlossPolicy, type: :policy do
  let(:superuser) { User.create!(email: "super_#{rand(10000)}@example.com", password: 'password123', superuser: true) }
  let(:regular_user) { User.create!(email: "regular_#{rand(10000)}@example.com", password: 'password123') }
  let(:word) { Word.create!(representation: 'שלום', part_of_speech: 'noun') }
  let(:gloss) { Gloss.create!(text: 'peace', word: word) }

  after(:each) do
    User.destroy_all
    Word.destroy_all
    Gloss.destroy_all
  end

  describe '#index?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, gloss).index?).to be true
      expect(described_class.new(superuser, gloss).index?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, gloss).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows access for any authenticated user' do
      expect(described_class.new(regular_user, gloss).show?).to be true
      expect(described_class.new(superuser, gloss).show?).to be true
    end

    it 'denies access for unauthenticated user' do
      expect(described_class.new(nil, gloss).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, gloss).create?).to be true
      expect(described_class.new(regular_user, gloss).create?).to be false
      expect(described_class.new(nil, gloss).create?).to be false
    end
  end

  describe '#new?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, gloss).new?).to be true
      expect(described_class.new(regular_user, gloss).new?).to be false
      expect(described_class.new(nil, gloss).new?).to be false
    end
  end

  describe '#update?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, gloss).update?).to be true
      expect(described_class.new(regular_user, gloss).update?).to be false
      expect(described_class.new(nil, gloss).update?).to be false
    end
  end

  describe '#edit?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, gloss).edit?).to be true
      expect(described_class.new(regular_user, gloss).edit?).to be false
      expect(described_class.new(nil, gloss).edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows access for superusers only' do
      expect(described_class.new(superuser, gloss).destroy?).to be true
      expect(described_class.new(regular_user, gloss).destroy?).to be false
      expect(described_class.new(nil, gloss).destroy?).to be false
    end
  end
end
