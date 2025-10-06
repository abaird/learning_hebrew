require 'rails_helper'

RSpec.describe "Imports", type: :request do
  let(:superuser) { User.find_or_create_by!(email: 'super@example.com') { |u| u.password = 'password'; u.superuser = true } }
  let(:regular_user) { User.find_or_create_by!(email: 'regular@example.com') { |u| u.password = 'password'; u.superuser = false } }

  describe "GET /import (new)" do
    context "as superuser" do
      before { sign_in superuser }

      it "returns http success" do
        get new_import_path
        expect(response).to have_http_status(:success)
      end

      it "displays upload form" do
        get new_import_path
        expect(response.body).to include('file')
      end
    end

    context "as regular user" do
      before { sign_in regular_user }

      it "redirects with authorization error" do
        get new_import_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context "as unauthenticated user" do
      it "redirects to sign in" do
        get new_import_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /import (create)" do
    let(:valid_file_content) do
      <<~TXT
        שָׁלוֹם
        peace
        hello
        ---
        אֱלֹהִים
        God
        gods
        ---
      TXT
    end

    let(:invalid_file_content) do
      <<~TXT
        peace
        hello
        ---
      TXT
    end

    context "as superuser" do
      before { sign_in superuser }

      it "creates words and glosses from valid file" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        expect {
          post import_path, params: { file: file }
        }.to change(Word, :count).by(2)
         .and change(Gloss, :count).by(4) # 2 glosses for first word + 2 for second word

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Successfully imported 2 words')
      end

      it "creates words with 'unknown' part of speech category" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        post import_path, params: { file: file }

        word = Word.find_by(representation: 'שָׁלוֹם')
        expect(word.part_of_speech_category&.abbrev).to eq('?')
      end

      it "updates existing word and replaces glosses" do
        existing_word = Word.create!(representation: 'שָׁלוֹם')
        existing_word.glosses.create!(text: 'old gloss')

        file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        expect {
          post import_path, params: { file: file }
        }.to change(Word, :count).by(1) # Only one new word (אֱלֹהִים)
         .and change(Gloss, :count).by(3) # Old gloss destroyed (-1), 2 new for existing word, 2 for new word = +3

        word = Word.find_by(representation: 'שָׁלוֹם')
        expect(word.glosses.pluck(:text)).to match_array([ 'peace', 'hello' ])
      end

      it "treats words with different nikkud as different words" do
        file_content = <<~TXT
          דָּבָר
          word
          thing
          ---
          דְּבַר
          spoke
          ---
        TXT

        file = Rack::Test::UploadedFile.new(
          StringIO.new(file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        expect {
          post import_path, params: { file: file }
        }.to change(Word, :count).by(2)

        word1 = Word.find_by(representation: 'דָּבָר')
        word2 = Word.find_by(representation: 'דְּבַר')
        expect(word1).to be_present
        expect(word2).to be_present
        expect(word1.id).not_to eq(word2.id)
      end

      it "shows error for invalid file format" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new(invalid_file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        expect {
          post import_path, params: { file: file }
        }.not_to change(Word, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('must start with a Hebrew word')
      end

      it "shows error if no file provided" do
        post import_path, params: {}

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('No file provided')
      end

      describe "JSON format import" do
        let!(:verb_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Verb') { |pos| pos.abbrev = 'v' } }
        let!(:noun_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Noun') { |pos| pos.abbrev = 'n' } }

        it "imports word with metadata from JSON" do
          json_content = <<~JSON
            [
              {
                "word": "לָמַד",
                "glosses": ["to learn", "to study"],
                "pos": "Verb",
                "pos_detail": {
                  "binyan": "qal",
                  "conjugation": "3MS"
                }
              }
            ]
          JSON

          file = Rack::Test::UploadedFile.new(
            StringIO.new(json_content),
            'application/json',
            original_filename: 'dictionary.json'
          )

          expect {
            post import_path, params: { file: file }
          }.to change(Word, :count).by(1)
           .and change(Gloss, :count).by(2)

          word = Word.find_by(representation: 'לָמַד')
          expect(word.part_of_speech_category).to eq(verb_pos)
          expect(word.binyan).to eq('qal')
          expect(word.conjugation).to eq('3MS')
          expect(word.glosses.pluck(:text)).to match_array([ 'to learn', 'to study' ])
        end

        it "merges all metadata fields into form_metadata" do
          json_content = <<~JSON
            [
              {
                "word": "בַּ֫יִת",
                "lesson_introduced": 5,
                "function": "a house",
                "glosses": ["house"],
                "pos_type": "Lexical Category",
                "pos": "Noun",
                "pos_detail": {
                  "gender": "masculine",
                  "number": "singular"
                }
              }
            ]
          JSON

          file = Rack::Test::UploadedFile.new(
            StringIO.new(json_content),
            'application/json',
            original_filename: 'dictionary.json'
          )

          post import_path, params: { file: file }

          word = Word.find_by(representation: 'בַּ֫יִת')
          expect(word.form_metadata['gender']).to eq('masculine')
          expect(word.form_metadata['number']).to eq('singular')
          expect(word.form_metadata['pos_type']).to eq('Lexical Category')
          expect(word.form_metadata['lesson_introduced']).to eq(5)
          expect(word.form_metadata['function']).to eq('a house')
        end

        it "links words using lexeme_of_hint" do
          # First import the parent word
          parent_json = <<~JSON
            [
              {
                "word": "בַּ֫יִת",
                "glosses": ["house"],
                "pos": "Noun",
                "pos_detail": {
                  "number": "singular"
                }
              }
            ]
          JSON

          file1 = Rack::Test::UploadedFile.new(
            StringIO.new(parent_json),
            'application/json',
            original_filename: 'parent.json'
          )

          post import_path, params: { file: file1 }
          parent = Word.find_by(representation: 'בַּ֫יִת')

          # Then import the linked word
          linked_json = <<~JSON
            [
              {
                "word": "בָּתִּים",
                "glosses": ["houses"],
                "pos": "Noun",
                "lexeme_of_hint": "בַּ֫יִת",
                "pos_detail": {
                  "number": "plural"
                }
              }
            ]
          JSON

          file2 = Rack::Test::UploadedFile.new(
            StringIO.new(linked_json),
            'application/json',
            original_filename: 'linked.json'
          )

          expect {
            post import_path, params: { file: file2 }
          }.to change(Word, :count).by(1)

          linked_word = Word.find_by(representation: 'בָּתִּים')
          expect(linked_word.lexeme_id).to eq(parent.id)
          expect(linked_word.lexeme).to eq(parent)
        end

        it "handles lexeme_of_hint when parent doesn't exist yet" do
          json_content = <<~JSON
            [
              {
                "word": "בָּתִּים",
                "glosses": ["houses"],
                "pos": "Noun",
                "lexeme_of_hint": "בַּ֫יִת",
                "pos_detail": {
                  "number": "plural"
                }
              }
            ]
          JSON

          file = Rack::Test::UploadedFile.new(
            StringIO.new(json_content),
            'application/json',
            original_filename: 'dictionary.json'
          )

          post import_path, params: { file: file }

          word = Word.find_by(representation: 'בָּתִּים')
          expect(word.lexeme_id).to be_nil  # Parent not found, lexeme_id stays null
        end

        it "uses Unknown POS if category doesn't exist" do
          json_content = <<~JSON
            [
              {
                "word": "test",
                "glosses": ["test"],
                "pos": "NonexistentPOS",
                "pos_detail": {}
              }
            ]
          JSON

          file = Rack::Test::UploadedFile.new(
            StringIO.new(json_content),
            'application/json',
            original_filename: 'dictionary.json'
          )

          expect {
            post import_path, params: { file: file }
          }.to change(Word, :count).by(1)

          word = Word.find_by(representation: 'test')
          expect(word.part_of_speech_category&.abbrev).to eq('?')
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context "as regular user" do
      before { sign_in regular_user }

      it "redirects with authorization error" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_file_content),
          'text/plain',
          original_filename: 'dictionary.txt'
        )

        post import_path, params: { file: file }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
