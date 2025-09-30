require 'rails_helper'

RSpec.describe "Gloss Forms Integration", type: :request do
  fixtures :users, :decks, :words, :deck_words

  let(:superuser_account) { users(:superuser) }
  let(:word1) { words(:shalom) }
  let(:word2) { words(:toda) }

  let(:valid_attributes) {
    {
      text: "peace, greeting, hello"
    }
  }

  before { sign_in superuser_account }

  describe "Gloss form with word dropdown" do
    describe "GET /glosses/new" do
      it "renders form with word dropdown" do
        get new_gloss_url
        expect(response).to be_successful
        expect(response.body).to include('name="gloss[word_id]"')
        expect(response.body).to include('<select')
        expect(response.body).to include(word1.representation)
        expect(response.body).to include(word2.representation)
      end
    end

    describe "POST /glosses with word selection" do
      context "with valid word_id" do
        it "creates gloss associated with selected word" do
          expect {
            post glosses_url, params: {
              gloss: valid_attributes.merge(word_id: word1.id)
            }
          }.to change(Gloss, :count).by(1)

          gloss = Gloss.last
          expect(gloss.word).to eq(word1)
          expect(gloss.text).to eq(valid_attributes[:text])
        end
      end

      context "with invalid word_id" do
        it "does not create gloss with non-existent word" do
          expect {
            post glosses_url, params: {
              gloss: valid_attributes.merge(word_id: 999999)
            }
          }.to change(Gloss, :count).by(0)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "without word_id" do
        it "does not create gloss without word selection" do
          expect {
            post glosses_url, params: { gloss: valid_attributes }
          }.to change(Gloss, :count).by(0)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "GET /glosses/:id/edit" do
      let(:gloss) { Gloss.create!(valid_attributes.merge(word: word1)) }

      it "renders form with word dropdown showing current selection" do
        get edit_gloss_url(gloss)
        expect(response).to be_successful
        expect(response.body).to include('name="gloss[word_id]"')
        expect(response.body).to include('<select')
        expect(response.body).to include('selected="selected"')
        expect(response.body).to include(word1.representation)
        expect(response.body).to include(word2.representation)
      end
    end

    describe "PATCH /glosses/:id with word selection changes" do
      let(:gloss) { Gloss.create!(valid_attributes.merge(word: word1)) }

      it "updates gloss word association" do
        patch gloss_url(gloss), params: {
          gloss: valid_attributes.merge(word_id: word2.id)
        }

        gloss.reload
        expect(gloss.word).to eq(word2)
      end

      it "does not update with invalid word_id" do
        original_word = gloss.word
        patch gloss_url(gloss), params: {
          gloss: valid_attributes.merge(word_id: 999999)
        }

        expect(response).to have_http_status(:unprocessable_content)
        gloss.reload
        expect(gloss.word).to eq(original_word)
      end
    end
  end
end