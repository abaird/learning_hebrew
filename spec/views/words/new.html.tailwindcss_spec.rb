require 'rails_helper'

RSpec.describe "words/new", type: :view do
  before(:each) do
    assign(:word, Word.new(
      representation: "MyString",
      part_of_speech: "MyString",
      mnemonic: "MyText",
      pronunciation_url: "MyString",
      picture_url: "MyString"
    ))
  end

  it "renders new word form" do
    render

    assert_select "form[action=?][method=?]", words_path, "post" do
      assert_select "input[name=?]", "word[representation]"

      assert_select "input[name=?]", "word[part_of_speech]"

      assert_select "textarea[name=?]", "word[mnemonic]"

      assert_select "input[name=?]", "word[pronunciation_url]"

      assert_select "input[name=?]", "word[picture_url]"

      assert_select "input[name=?]", "word[deck_id]"
    end
  end
end
