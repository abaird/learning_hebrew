require 'rails_helper'

RSpec.describe "decks/new", type: :view do
  before(:each) do
    assign(:deck, Deck.new(
      name: "MyString",
      description: "MyText",
      user: nil
    ))
  end

  it "renders new deck form" do
    render

    assert_select "form[action=?][method=?]", decks_path, "post" do
      assert_select "input[name=?]", "deck[name]"

      assert_select "textarea[name=?]", "deck[description]"

      assert_select "input[name=?]", "deck[user_id]"
    end
  end
end
