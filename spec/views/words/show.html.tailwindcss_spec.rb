require 'rails_helper'

RSpec.describe "words/show", type: :view do
  before(:each) do
    assign(:word, Word.create!(
      hebrew: "Hebrew",
      part_of_speech: "Part Of Speech",
      mnemonic: "MyText",
      pronunciation_audio_url: "Pronunciation Audio Url",
      picture_url: "Picture Url",
      deck: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Hebrew/)
    expect(rendered).to match(/Part Of Speech/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/Pronunciation Audio Url/)
    expect(rendered).to match(/Picture Url/)
    expect(rendered).to match(//)
  end
end
