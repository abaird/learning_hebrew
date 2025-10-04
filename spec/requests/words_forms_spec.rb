require 'rails_helper'

RSpec.describe "Word Forms Integration", type: :request do
  fixtures :users, :decks, :words, :deck_words

  let(:superuser_account) { users(:superuser) }
  let(:deck1) { decks(:basic_deck) }
  let(:deck2) { decks(:advanced_deck) }

  let(:valid_attributes) {
    {
      representation: "שלום",
      mnemonic: "Peace and greeting",
      pronunciation_url: "https://example.com/shalom.mp3",
      picture_url: "https://example.com/peace.jpg"
    }
  }

  before { sign_in superuser_account }

  describe "Word form with deck checkboxes" do
    describe "GET /words/new" do
      it "renders form with deck checkboxes" do
        get new_word_url
        expect(response).to be_successful
        expect(response.body).to include('name="word[deck_ids][]"')
        expect(response.body).to include(deck1.name)
        expect(response.body).to include(deck2.name)
      end
    end

    describe "POST /words with deck selection" do
      context "with deck_ids in parameters" do
        it "creates word and associates with selected decks" do
          expect {
            post words_url, params: {
              word: valid_attributes.merge(deck_ids: [ deck1.id, deck2.id ])
            }
          }.to change(Word, :count).by(1)

          word = Word.last
          expect(word.decks).to match_array([ deck1, deck2 ])
        end

        it "creates word with single deck" do
          expect {
            post words_url, params: {
              word: valid_attributes.merge(deck_ids: [ deck1.id ])
            }
          }.to change(Word, :count).by(1)

          word = Word.last
          expect(word.decks).to match_array([ deck1 ])
        end

        it "creates word with no deck selection" do
          expect {
            post words_url, params: { word: valid_attributes }
          }.to change(Word, :count).by(1)

          word = Word.last
          expect(word.decks).to be_empty
        end
      end
    end

    describe "GET /words/:id/edit" do
      let(:word) { Word.create!(valid_attributes) }

      before do
        word.decks << deck1
      end

      it "renders form with pre-selected deck checkboxes" do
        get edit_word_url(word)
        expect(response).to be_successful
        expect(response.body).to include('name="word[deck_ids][]"')
        expect(response.body).to include('checked="checked"')
        expect(response.body).to include(deck1.name)
        expect(response.body).to include(deck2.name)
      end
    end

    describe "PATCH /words/:id with deck selection changes" do
      let(:word) { Word.create!(valid_attributes) }

      before do
        word.decks << deck1
      end

      it "updates word deck associations" do
        patch word_url(word), params: {
          word: valid_attributes.merge(deck_ids: [ deck2.id ])
        }

        word.reload
        expect(word.decks).to match_array([ deck2 ])
      end

      it "removes all deck associations when none selected" do
        patch word_url(word), params: {
          word: valid_attributes.merge(deck_ids: [])
        }

        word.reload
        expect(word.decks).to be_empty
      end
    end
  end
end
