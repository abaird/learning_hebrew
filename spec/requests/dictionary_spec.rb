require 'rails_helper'

RSpec.describe "Dictionaries", type: :request do
  let!(:user) { User.find_or_create_by!(email: 'dictionary_test@example.com') { |u| u.password = 'password'; u.superuser = false } }

  before do
    sign_in user
  end

  it_behaves_like "paginatable", :dictionary_index, Word, { representation: "שלום" }, -> { "/dictionary" }

  describe "GET /index" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays words sorted alphabetically in Hebrew" do
      word1 = Word.create!(representation: 'ב')
      word2 = Word.create!(representation: 'א')
      word3 = Word.create!(representation: 'ג')

      get root_path
      expect(response.body).to match(/א.*ב.*ג/m)
    end

    it "displays glosses for each word" do
      word = Word.create!(representation: 'שלום')
      word.glosses.create!(text: 'peace')
      word.glosses.create!(text: 'hello')

      get root_path
      expect(response.body).to include('peace')
      expect(response.body).to include('hello')
    end

    it "shows message when word has no glosses" do
      word = Word.create!(representation: 'שלום')

      get root_path
      expect(response.body).to include('No definitions yet')
    end

    it "paginates results" do
      30.times do |i|
        Word.create!(representation: "word#{i}")
      end

      get root_path
      expect(response.body).to include('next')
    end

    context "with dictionary entry filtering" do
      let(:verb_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Verb') { |pos| pos.abbrev = 'v' } }
      let(:noun_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Noun') { |pos| pos.abbrev = 'n' } }

      it "shows only 3MS verbs, not other conjugations" do
        # Dictionary entry: 3MS verb
        verb_3ms = Word.create!(
          representation: 'לָמַד',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '3MS' }
        )
        verb_3ms.glosses.create!(text: 'he learned')

        # Not dictionary entry: 1CS verb
        verb_1cs = Word.create!(
          representation: 'לָמַדְתִּי',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '1CS' }
        )
        verb_1cs.glosses.create!(text: 'I learned')

        get dictionary_path, params: { show_all: 'false' }

        expect(response.body).to include('לָמַד')
        expect(response.body).to include('he learned')
        expect(response.body).not_to include('לָמַדְתִּי')
        expect(response.body).not_to include('I learned')
      end

      it "shows only singular nouns, not plural forms" do
        # Dictionary entry: singular noun
        singular_noun = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular' }
        )
        singular_noun.glosses.create!(text: 'son')

        # Not dictionary entry: plural noun
        plural_noun = Word.create!(
          representation: 'בָּנִים',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'plural' }
        )
        plural_noun.glosses.create!(text: 'sons')

        get dictionary_path, params: { show_all: 'false' }

        expect(response.body).to include('בֵּן')
        expect(response.body).to include('son')
        expect(response.body).not_to include('בָּנִים')
        expect(response.body).not_to include('sons')
      end

      it "excludes construct state nouns from dictionary" do
        # Dictionary entry: singular absolute noun
        absolute_noun = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', status: 'absolute' }
        )
        absolute_noun.glosses.create!(text: 'son')

        # Not dictionary entry: singular construct noun
        construct_noun = Word.create!(
          representation: 'בֶּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', status: 'construct' }
        )
        construct_noun.glosses.create!(text: 'son of')

        get dictionary_path, params: { show_all: 'false' }

        expect(response.body).to include('בֵּן')
        expect(response.body).to include('son')
        expect(response.body).not_to include('בֶּן')
        expect(response.body).not_to include('son of')
      end

      it "excludes words with lexeme_id (forms) from dictionary" do
        # Dictionary entry parent
        parent = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular' }
        )
        parent.glosses.create!(text: 'son')

        # Form linked to parent
        form = Word.create!(
          representation: 'בָּנִים',
          part_of_speech_category: noun_pos,
          lexeme_id: parent.id,
          form_metadata: { number: 'plural' }
        )
        form.glosses.create!(text: 'sons')

        get dictionary_path, params: { show_all: 'false' }

        expect(response.body).to include('בֵּן')
        expect(response.body).to include('son')
        expect(response.body).not_to include('בָּנִים')
        expect(response.body).not_to include('sons')
      end
    end

    context "with search functionality" do
      let(:verb_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Verb') { |pos| pos.abbrev = 'v' } }
      let(:noun_pos) { PartOfSpeechCategory.find_or_create_by!(name: 'Noun') { |pos| pos.abbrev = 'n' } }

      it "searches words by representation" do
        word1 = Word.create!(representation: 'שָׁלוֹם', part_of_speech_category: noun_pos, form_metadata: { number: 'singular' })
        word1.glosses.create!(text: 'peace')

        word2 = Word.create!(representation: 'בֵּן', part_of_speech_category: noun_pos, form_metadata: { number: 'singular' })
        word2.glosses.create!(text: 'son')

        get dictionary_path, params: { q: 'שָׁלוֹם' }

        expect(response.body).to include('שָׁלוֹם')
        expect(response.body).not_to include('בֵּן')
      end

      it "searches words by gloss" do
        word1 = Word.create!(representation: 'שָׁלוֹם', part_of_speech_category: noun_pos, form_metadata: { number: 'singular' })
        word1.glosses.create!(text: 'peace')

        word2 = Word.create!(representation: 'בֵּן', part_of_speech_category: noun_pos, form_metadata: { number: 'singular' })
        word2.glosses.create!(text: 'son')

        get dictionary_path, params: { q: 'peace' }

        expect(response.body).to include('שָׁלוֹם')
        expect(response.body).to include('peace')
        expect(response.body).not_to include('בֵּן')
      end

      it "filters by part of speech" do
        verb = Word.create!(representation: 'לָמַד', part_of_speech_category: verb_pos, form_metadata: { conjugation: '3MS' })
        verb.glosses.create!(text: 'he learned')

        noun = Word.create!(representation: 'בֵּן', part_of_speech_category: noun_pos, form_metadata: { number: 'singular' })
        noun.glosses.create!(text: 'son')

        get dictionary_path, params: { pos_id: verb_pos.id }

        expect(response.body).to include('לָמַד')
        expect(response.body).not_to include('בֵּן')
      end

      it "filters by binyan" do
        qal_verb = Word.create!(
          representation: 'לָמַד',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '3MS', binyan: 'qal' }
        )
        qal_verb.glosses.create!(text: 'he learned')

        piel_verb = Word.create!(
          representation: 'לִמֵּד',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '3MS', binyan: 'piel' }
        )
        piel_verb.glosses.create!(text: 'he taught')

        get dictionary_path, params: { binyan: 'qal' }

        expect(response.body).to include('לָמַד')
        expect(response.body).not_to include('לִמֵּד')
      end

      it "filters by number" do
        singular = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular' }
        )
        singular.glosses.create!(text: 'son')

        plural = Word.create!(
          representation: 'בָּנִים',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'plural' }
        )
        plural.glosses.create!(text: 'sons')

        get dictionary_path, params: { number: 'singular' }

        expect(response.body).to include('בֵּן')
        expect(response.body).not_to include('בָּנִים')
      end

      it "shows all words when show_all is true" do
        singular = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular' }
        )
        singular.glosses.create!(text: 'son')

        plural = Word.create!(
          representation: 'בָּנִים',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'plural' }
        )
        plural.glosses.create!(text: 'sons')

        get dictionary_path, params: { show_all: 'true' }

        expect(response.body).to include('בֵּן')
        expect(response.body).to include('בָּנִים')
      end

      it "combines multiple filters" do
        qal_verb = Word.create!(
          representation: 'לָמַד',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '3MS', binyan: 'qal' }
        )
        qal_verb.glosses.create!(text: 'he learned')

        piel_verb = Word.create!(
          representation: 'לִמֵּד',
          part_of_speech_category: verb_pos,
          form_metadata: { conjugation: '3MS', binyan: 'piel' }
        )
        piel_verb.glosses.create!(text: 'he taught')

        noun = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular' }
        )
        noun.glosses.create!(text: 'son')

        get dictionary_path, params: { pos_id: verb_pos.id, binyan: 'qal' }

        expect(response.body).to include('לָמַד')
        expect(response.body).not_to include('לִמֵּד')
        expect(response.body).not_to include('בֵּן')
      end

      it "filters by exact lesson number" do
        lesson_5 = Word.create!(
          representation: 'שָׁלוֹם',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', lesson_introduced: 5 }
        )
        lesson_5.glosses.create!(text: 'peace')

        lesson_10 = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', lesson_introduced: 10 }
        )
        lesson_10.glosses.create!(text: 'son')

        get dictionary_path, params: { lesson: 5, lesson_mode: 'exact' }

        expect(response.body).to include('שָׁלוֹם')
        expect(response.body).not_to include('בֵּן')
      end

      it "filters by lesson number or less" do
        lesson_3 = Word.create!(
          representation: 'אֱלֹהִים',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', lesson_introduced: 3 }
        )
        lesson_3.glosses.create!(text: 'God')

        lesson_5 = Word.create!(
          representation: 'שָׁלוֹם',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', lesson_introduced: 5 }
        )
        lesson_5.glosses.create!(text: 'peace')

        lesson_10 = Word.create!(
          representation: 'בֵּן',
          part_of_speech_category: noun_pos,
          form_metadata: { number: 'singular', lesson_introduced: 10 }
        )
        lesson_10.glosses.create!(text: 'son')

        get dictionary_path, params: { lesson: 5, lesson_mode: 'or_less' }

        expect(response.body).to include('אֱלֹהִים')
        expect(response.body).to include('שָׁלוֹם')
        expect(response.body).not_to include('בֵּן')
      end
    end
  end
end
