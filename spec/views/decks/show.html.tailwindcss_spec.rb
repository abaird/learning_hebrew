require 'rails_helper'

RSpec.describe "decks/show", type: :view do
  fixtures :users, :decks
  before(:each) do
    assign(:deck, decks(:basic_deck))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Basic Hebrew Words/)
    expect(rendered).to match(/A collection of basic Hebrew vocabulary/)
  end
end
