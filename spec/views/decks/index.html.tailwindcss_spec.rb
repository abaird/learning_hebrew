require 'rails_helper'

RSpec.describe "decks/index", type: :view do
  before(:each) do
    assign(:decks, [
      Deck.create!(
        name: "Name",
        description: "MyText",
        user: nil
      ),
      Deck.create!(
        name: "Name",
        description: "MyText",
        user: nil
      )
    ])
  end

  it "renders a list of decks" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
