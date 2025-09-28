require 'rails_helper'

RSpec.describe "decks/edit", type: :view do
  fixtures :users, :decks

  let(:deck) { decks(:basic_deck) }

  before(:each) do
    assign(:deck, deck)
  end

  it "renders the edit deck form" do
    render

    assert_select "form[action=?][method=?]", deck_path(deck), "post" do
      assert_select "input[name=?]", "deck[name]"

      assert_select "textarea[name=?]", "deck[description]"

      assert_select "input[name=?]", "deck[user_id]"
    end
  end
end
