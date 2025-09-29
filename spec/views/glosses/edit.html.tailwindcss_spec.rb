require 'rails_helper'

RSpec.describe "glosses/edit", type: :view do
  fixtures :users, :decks, :words, :deck_words, :glosses
  let(:gloss) { glosses(:shalom_peace) }

  before(:each) do
    assign(:gloss, gloss)
  end

  it "renders the edit gloss form" do
    render

    assert_select "form[action=?][method=?]", gloss_path(gloss), "post" do
      assert_select "textarea[name=?]", "gloss[text]"

      assert_select "input[name=?]", "gloss[word_id]"
    end
  end
end
