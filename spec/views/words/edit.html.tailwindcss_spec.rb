require 'rails_helper'

RSpec.describe "words/edit", type: :view do
  let(:word) {
    Word.create!(
      hebrew: "MyString",
      part_of_speech: "MyString",
      mnemonic: "MyText",
      pronunciation_audio_url: "MyString",
      picture_url: "MyString",
      deck: nil
    )
  }

  before(:each) do
    assign(:word, word)
  end

  it "renders the edit word form" do
    render

    assert_select "form[action=?][method=?]", word_path(word), "post" do
      assert_select "input[name=?]", "word[hebrew]"

      assert_select "input[name=?]", "word[part_of_speech]"

      assert_select "textarea[name=?]", "word[mnemonic]"

      assert_select "input[name=?]", "word[pronunciation_audio_url]"

      assert_select "input[name=?]", "word[picture_url]"

      assert_select "input[name=?]", "word[deck_id]"
    end
  end
end
