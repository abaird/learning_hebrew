require 'rails_helper'

RSpec.describe "glosses/index", type: :view do
  fixtures :users, :decks, :words, :deck_words, :glosses
  before(:each) do
    assign(:glosses, Kaminari.paginate_array([
      glosses(:shalom_peace),
      glosses(:shalom_hello)
    ]).page(1).per(25))
  end

  it "renders a list of glosses" do
    render
    expect(rendered).to match(/peace/)
    expect(rendered).to match(/hello/)
  end
end
