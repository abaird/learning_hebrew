require 'rails_helper'

RSpec.describe "words/edit", type: :view do
  fixtures :users, :decks, :words, :deck_words
  let(:word) { words(:shalom) }

  before(:each) do
    assign(:word, word)
    assign(:pos_categories, PartOfSpeechCategory.all)
    assign(:genders, Gender.all)
    assign(:verb_forms, VerbForm.all)
    assign(:decks, [])
  end

  it "renders the edit word form" do
    render

    assert_select "form[action=?][method=?]", word_path(word), "post" do
      assert_select "input[name=?]", "word[representation]"

      assert_select "select[name=?]", "word[part_of_speech_category_id]"
      assert_select "select[name=?]", "word[gender_id]"
      assert_select "select[name=?]", "word[verb_form_id]"

      assert_select "textarea[name=?]", "word[mnemonic]"

      assert_select "input[name=?]", "word[pronunciation_url]"

      assert_select "input[name=?]", "word[picture_url]"
    end
  end
end
