require 'rails_helper'

RSpec.describe DeckWord, type: :model do
  describe 'associations' do
    it { should belong_to(:deck) }
    it { should belong_to(:word) }
  end

  describe 'validations' do
    let(:user) { User.create!(email: 'test@example.com', password: 'password123') }
    let(:deck) { Deck.create!(name: 'Test Deck', user: user) }
    let(:word) { Word.create!(representation: 'שלום', part_of_speech: 'noun') }

    it 'validates uniqueness of deck_id scoped to word_id' do
      DeckWord.create!(deck: deck, word: word)
      duplicate = DeckWord.new(deck: deck, word: word)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:deck_id]).to include("has already been taken")
    end

    it 'allows same word in different decks' do
      deck2 = Deck.create!(name: 'Test Deck 2', user: user)
      DeckWord.create!(deck: deck, word: word)

      expect(DeckWord.new(deck: deck2, word: word)).to be_valid
    end

    it 'allows different words in same deck' do
      word2 = Word.create!(representation: 'היי', part_of_speech: 'interjection')
      DeckWord.create!(deck: deck, word: word)

      expect(DeckWord.new(deck: deck, word: word2)).to be_valid
    end
  end
end