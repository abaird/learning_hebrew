require 'rails_helper'

RSpec.describe "glosses/new", type: :view do
  before(:each) do
    assign(:gloss, Gloss.new(
      text: "MyText",
      word: nil
    ))
  end

  it "renders new gloss form" do
    render

    assert_select "form[action=?][method=?]", glosses_path, "post" do
      assert_select "textarea[name=?]", "gloss[text]"

      assert_select "input[name=?]", "gloss[word_id]"
    end
  end
end
