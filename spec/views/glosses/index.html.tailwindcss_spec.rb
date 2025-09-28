require 'rails_helper'

RSpec.describe "glosses/index", type: :view do
  fixtures :users, :decks, :words, :glosses
  before(:each) do
    assign(:glosses, [
      glosses(:shalom_peace),
      glosses(:shalom_hello)
    ])
  end

  it "renders a list of glosses" do
    render
    expect(rendered).to match(/peace/)
    expect(rendered).to match(/hello/)
  end
end
