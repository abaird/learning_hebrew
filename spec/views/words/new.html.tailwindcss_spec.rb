require 'rails_helper'

RSpec.describe "words/new", type: :view do
  before(:each) do
    assign(:word, Word.new(
      representation: "MyString",
      mnemonic: "MyText",
      pronunciation_url: "MyString",
      picture_url: "MyString"
    ))
    assign(:pos_categories, PartOfSpeechCategory.all)
    assign(:decks, [])
  end

  it "renders new word form" do
    render

    assert_select "form[action=?][method=?]", words_path, "post" do
      assert_select "input[name=?]", "word[representation]"

      assert_select "select[name=?]", "word[part_of_speech_category_id]"

      assert_select "textarea[name=?]", "word[mnemonic]"

      assert_select "input[name=?]", "word[pronunciation_url]"

      assert_select "input[name=?]", "word[picture_url]"
    end
  end
end
