require 'rails_helper'

RSpec.describe "words/edit", type: :view do
  fixtures :users, :decks, :words
  let(:word) { words(:shalom) }

  before(:each) do
    assign(:word, word)
  end

  it "renders the edit word form" do
    render

    assert_select "form[action=?][method=?]", word_path(word), "post" do
      assert_select "input[name=?]", "word[representation]"

      assert_select "input[name=?]", "word[part_of_speech]"

      assert_select "textarea[name=?]", "word[mnemonic]"

      assert_select "input[name=?]", "word[pronunciation_url]"

      assert_select "input[name=?]", "word[picture_url]"

      assert_select "input[name=?]", "word[deck_id]"
    end
  end
end
