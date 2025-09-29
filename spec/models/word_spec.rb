require 'rails_helper'

RSpec.describe Word, type: :model do
  describe 'associations' do
    it { should have_many(:deck_words).dependent(:destroy) }
    it { should have_many(:decks).through(:deck_words) }
    it { should have_many(:glosses).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:representation) }
    it { should validate_presence_of(:part_of_speech) }
  end

  describe 'many-to-many relationship with decks' do
    let(:user) { User.create!(email: "word_test_#{rand(10000)}@example.com", password: 'password123') }
    let(:deck1) { Deck.create!(name: 'Deck 1', user: user) }
    let(:deck2) { Deck.create!(name: 'Deck 2', user: user) }
    let(:word) { Word.create!(representation: 'שלום', part_of_speech: 'noun') }

    after(:each) do
      User.destroy_all
      Deck.destroy_all
      Word.destroy_all
      DeckWord.destroy_all
    end

    it 'can belong to multiple decks' do
      word.decks << [ deck1, deck2 ]

      expect(word.decks.count).to eq(2)
      expect(word.decks).to include(deck1, deck2)
    end

    it 'can be removed from a deck without affecting other decks' do
      word.decks << [ deck1, deck2 ]
      deck1.words.delete(word)

      expect(word.decks).to include(deck2)
      expect(word.decks).not_to include(deck1)
      expect(deck2.words).to include(word)
    end
  end
end
