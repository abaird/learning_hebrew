require 'rails_helper'

RSpec.describe "glosses/show", type: :view do
  fixtures :users, :decks, :words, :deck_words, :glosses
  before(:each) do
    assign(:gloss, glosses(:shalom_peace))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/peace/)
  end
end
