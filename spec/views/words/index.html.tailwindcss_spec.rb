require 'rails_helper'

RSpec.describe "words/index", type: :view do
  before(:each) do
    assign(:words, [
      Word.create!(
        hebrew: "Hebrew",
        part_of_speech: "Part Of Speech",
        mnemonic: "MyText",
        pronunciation_audio_url: "Pronunciation Audio Url",
        picture_url: "Picture Url",
        deck: nil
      ),
      Word.create!(
        hebrew: "Hebrew",
        part_of_speech: "Part Of Speech",
        mnemonic: "MyText",
        pronunciation_audio_url: "Pronunciation Audio Url",
        picture_url: "Picture Url",
        deck: nil
      )
    ])
  end

  it "renders a list of words" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Hebrew".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Part Of Speech".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Pronunciation Audio Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Picture Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
