require 'rails_helper'

RSpec.describe "words/show", type: :view do
  fixtures :users, :decks, :words, :deck_words
  before(:each) do
    assign(:word, words(:shalom))
    assign(:back_url, words_path)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/שלום/)
    expect(rendered).to match(/Peace and greeting/)
  end
end
