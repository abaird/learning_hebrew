require 'rails_helper'

RSpec.describe "words/index", type: :view do
  fixtures :users, :decks, :words, :deck_words
  before(:each) do
    assign(:words, Kaminari.paginate_array([
      words(:shalom),
      words(:shalom)
    ]).page(1).per(25))
  end

  it "renders a list of words" do
    render
    expect(rendered).to match(/שלום/)
    expect(rendered).to match(/Peace and greeting/)
  end
end
