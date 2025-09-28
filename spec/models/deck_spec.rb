require 'rails_helper'

RSpec.describe Deck, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:deck_words).dependent(:destroy) }
    it { should have_many(:words).through(:deck_words) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'many-to-many relationship with words' do
    let(:user) { User.create!(email: 'test@example.com', password: 'password123') }
    let(:deck1) { Deck.create!(name: 'Deck 1', user: user) }
    let(:deck2) { Deck.create!(name: 'Deck 2', user: user) }
    let(:word) { Word.create!(representation: 'שלום', part_of_speech: 'noun') }

    it 'can have multiple words' do
      word2 = Word.create!(representation: 'היי', part_of_speech: 'interjection')
      deck1.words << [word, word2]

      expect(deck1.words.count).to eq(2)
      expect(deck1.words).to include(word, word2)
    end

    it 'can share words with other decks' do
      deck1.words << word
      deck2.words << word

      expect(deck1.words).to include(word)
      expect(deck2.words).to include(word)
      expect(word.decks).to include(deck1, deck2)
    end
  end
end