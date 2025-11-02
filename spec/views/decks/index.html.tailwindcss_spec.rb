require 'rails_helper'

RSpec.describe "decks/index", type: :view do
  fixtures :users, :decks
  before(:each) do
    assign(:decks, Kaminari.paginate_array([
      decks(:basic_deck),
      decks(:basic_deck)
    ]).page(1).per(25))
  end

  it "renders a list of decks" do
    render
    expect(rendered).to match(/Basic Hebrew Words/)
    expect(rendered).to match(/A collection of basic Hebrew vocabulary/)
  end
end
