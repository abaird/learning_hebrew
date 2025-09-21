require 'rails_helper'

RSpec.describe "glosses/index", type: :view do
  before(:each) do
    assign(:glosses, [
      Gloss.create!(
        text: "MyText",
        word: nil
      ),
      Gloss.create!(
        text: "MyText",
        word: nil
      )
    ])
  end

  it "renders a list of glosses" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
