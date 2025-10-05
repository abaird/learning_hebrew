require 'rails_helper'

RSpec.describe Word, type: :model do
  describe 'associations' do
    it { should have_many(:deck_words).dependent(:destroy) }
    it { should have_many(:decks).through(:deck_words) }
    it { should have_many(:glosses).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:representation) }
  end

  describe 'many-to-many relationship with decks' do
    let(:user) { User.create!(email: "word_test_#{rand(10000)}@example.com", password: 'password123') }
    let(:deck1) { Deck.create!(name: 'Deck 1', user: user) }
    let(:deck2) { Deck.create!(name: 'Deck 2', user: user) }
    let(:word) { Word.create!(representation: 'שלום') }

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

  describe '#formatted_glosses' do
    let(:word) { Word.create!(representation: 'שָׁלוֹם') }

    it 'returns empty string when word has no glosses' do
      expect(word.formatted_glosses).to eq('')
    end

    it 'formats single gloss with number' do
      word.glosses.create!(text: 'peace')

      expect(word.formatted_glosses).to eq('1) peace')
    end

    it 'formats multiple glosses as numbered list separated by commas' do
      word.glosses.create!(text: 'peace')
      word.glosses.create!(text: 'hello')
      word.glosses.create!(text: 'goodbye')

      expect(word.formatted_glosses).to eq('1) peace, 2) hello, 3) goodbye')
    end

    it 'formats two glosses correctly' do
      word.glosses.create!(text: 'woman')
      word.glosses.create!(text: 'wife')

      expect(word.formatted_glosses).to eq('1) woman, 2) wife')
    end
  end

  describe '.hebrew_sort_key' do
    it 'sorts Hebrew words without nikkud by consonant order' do
      # אבג order - aleph (0), bet (1), gimel (2)
      key_aleph = Word.hebrew_sort_key('א')
      key_bet = Word.hebrew_sort_key('ב')
      key_gimel = Word.hebrew_sort_key('ג')

      expect(key_aleph).to eq([ [ 0, 0 ] ])
      expect(key_bet).to eq([ [ 1, 0 ] ])
      expect(key_gimel).to eq([ [ 2, 0 ] ])

      # Verify sort order
      expect(key_aleph <=> key_bet).to eq(-1)
      expect(key_bet <=> key_gimel).to eq(-1)
    end

    it 'sorts words with nikkud using vowels as secondary sort key' do
      # Same consonant (aleph=0), different vowels
      # אַ - aleph with patach (vowel=1, "a" sound)
      # אִ - aleph with hireq (vowel=5, "i" sound)
      key_patach = Word.hebrew_sort_key('אַ')
      key_hireq = Word.hebrew_sort_key('אִ')

      expect(key_patach).to eq([ [ 0, 1 ] ])  # aleph, patach
      expect(key_hireq).to eq([ [ 0, 5 ] ])   # aleph, hireq

      # Patach (a) should come before hireq (i)
      expect(key_patach <=> key_hireq).to eq(-1)
    end

    it 'sorts complete words with multiple consonants and vowels' do
      # אַיֵּה (ayeh - "where") - aleph-patach, yod, he
      # אִישׁ (ish - "man") - aleph-hireq, yod, shin
      key_ayeh = Word.hebrew_sort_key('אַיֵּה')
      key_ish = Word.hebrew_sort_key('אִישׁ')

      # First character: both aleph (0), but patach (1) < hireq (5)
      expect(key_ayeh.first).to eq([ 0, 1 ])
      expect(key_ish.first).to eq([ 0, 5 ])

      # ayeh should sort before ish
      expect(key_ayeh <=> key_ish).to eq(-1)
    end

    it 'returns infinity for blank text' do
      expect(Word.hebrew_sort_key('')).to eq([ Float::INFINITY ])
      expect(Word.hebrew_sort_key(nil)).to eq([ Float::INFINITY ])
    end

    it 'returns infinity for non-Hebrew text' do
      # Text that is not blank but contains no Hebrew characters
      expect(Word.hebrew_sort_key('abc')).to eq([ [ Float::INFINITY, 0 ] ])
    end
  end

  describe 'form_metadata JSONB queries' do
    it 'can query words by gender in form_metadata' do
      # Create words with different genders in form_metadata
      masculine_word = Word.create!(
        representation: 'גָּדוֹל',
        form_metadata: { gender: 'masculine' }
      )
      feminine_word = Word.create!(
        representation: 'גְּדוֹלָה',
        form_metadata: { gender: 'feminine' }
      )
      word_without_gender = Word.create!(
        representation: 'שָׁלוֹם',
        form_metadata: {}
      )

      # Query for masculine words using JSONB operator
      results = Word.where("form_metadata->>'gender' = ?", 'masculine')

      expect(results).to include(masculine_word)
      expect(results).not_to include(feminine_word)
      expect(results).not_to include(word_without_gender)
    end
  end
end
