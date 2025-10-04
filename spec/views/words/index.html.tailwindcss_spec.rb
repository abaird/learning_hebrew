require 'rails_helper'

RSpec.describe "words/index", type: :view do
  fixtures :users, :decks, :words, :deck_words
  before(:each) do
    assign(:words, [
      words(:shalom),
      words(:shalom)
    ])
  end

  it "renders a list of words" do
    render
    expect(rendered).to match(/שלום/)
    expect(rendered).to match(/Peace and greeting/)
  end
end
