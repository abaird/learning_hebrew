require 'rails_helper'

RSpec.describe "Dictionaries", type: :request do
  let!(:user) { User.find_or_create_by!(email: 'dictionary_test@example.com') { |u| u.password = 'password'; u.superuser = false } }

  before do
    sign_in user
  end

  describe "GET /index" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays words sorted alphabetically in Hebrew" do
      word1 = Word.create!(representation: 'ב', part_of_speech: 'noun')
      word2 = Word.create!(representation: 'א', part_of_speech: 'verb')
      word3 = Word.create!(representation: 'ג', part_of_speech: 'adjective')

      get root_path
      expect(response.body).to match(/א.*ב.*ג/m)
    end

    it "displays glosses for each word" do
      word = Word.create!(representation: 'שלום', part_of_speech: 'noun')
      word.glosses.create!(text: 'peace')
      word.glosses.create!(text: 'hello')

      get root_path
      expect(response.body).to include('peace')
      expect(response.body).to include('hello')
    end

    it "shows message when word has no glosses" do
      word = Word.create!(representation: 'שלום', part_of_speech: 'noun')

      get root_path
      expect(response.body).to include('No definitions yet')
    end

    it "paginates results" do
      30.times do |i|
        Word.create!(representation: "word#{i}", part_of_speech: 'noun')
      end

      get root_path
      expect(response.body).to include('next')
    end
  end
end
