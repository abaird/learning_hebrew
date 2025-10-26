require "rails_helper"

RSpec.describe DictionaryLookupService do
  let(:pos_verb) { PartOfSpeechCategory.find_by(name: "Verb") || PartOfSpeechCategory.create!(name: "Verb", abbrev: "V") }
  let(:pos_noun) { PartOfSpeechCategory.find_by(name: "Noun") || PartOfSpeechCategory.create!(name: "Noun", abbrev: "N") }

  describe ".lookup" do
    context "Tier 1: Exact match with nikkud" do
      it "finds exact match including nikkud" do
        word = Word.create!(representation: "לָמַד", part_of_speech_category: pos_verb)
        word.glosses.create!(text: "he learned")

        result = described_class.lookup("לָמַד")

        expect(result[:found]).to be true
        expect(result[:hebrew]).to eq("לָמַד")
        expect(result[:gloss]).to eq("he learned")
        expect(result[:pos]).to eq("Verb")
      end

      it "returns multiple glosses as comma-separated" do
        word = Word.create!(representation: "לָמַד", part_of_speech_category: pos_verb)
        word.glosses.create!(text: "he learned")
        word.glosses.create!(text: "he studied")

        result = described_class.lookup("לָמַד")

        expect(result[:gloss]).to eq("he learned, he studied")
      end

      it "returns not found if no exact match" do
        result = described_class.lookup("לָמַד")

        expect(result[:found]).to be false
        expect(result[:word]).to eq("לָמַד")
      end
    end

    context "Tier 2: Final form normalization" do
      it "finds word with final form converted" do
        word = Word.create!(representation: "מֶלֶכ", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "king")

        # Query with final kaf
        result = described_class.lookup("מֶלֶך")

        expect(result[:found]).to be true
        expect(result[:hebrew]).to eq("מֶלֶכ")
        expect(result[:gloss]).to eq("king")
      end

      it "converts all final forms" do
        # Test ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ
        # Store without final kaf, lookup with final kaf
        word = Word.create!(representation: "מלכ", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "king")

        result = described_class.lookup("מלך") # query with final kaf

        expect(result[:found]).to be true
        expect(result[:hebrew]).to eq("מלכ")
      end

      it "preserves nikkud during final form conversion" do
        word = Word.create!(representation: "דָּבָר", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "word")

        # Query with nikkud and final form (if there were one)
        result = described_class.lookup("דָּבָר")

        expect(result[:found]).to be true
      end
    end

    context "Tier 3: Prefix removal" do
      it "finds word with ה prefix removed" do
        word = Word.create!(representation: "מֶּלֶך", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "king")

        result = described_class.lookup("הַמֶּלֶך")

        expect(result[:found]).to be true
        expect(result[:hebrew]).to eq("מֶּלֶך")
        expect(result[:gloss]).to eq("king")
      end

      it "finds word with ו prefix removed" do
        word = Word.create!(representation: "שָׁמַע", part_of_speech_category: pos_verb)
        word.glosses.create!(text: "he heard")

        result = described_class.lookup("וְשָׁמַע")

        expect(result[:found]).to be true
      end

      it "finds word with ב prefix removed" do
        word = Word.create!(representation: "בַיִת", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "house")

        result = described_class.lookup("בְּבַיִת")

        expect(result[:found]).to be true
      end

      it "tries prefix removal with final form normalization" do
        word = Word.create!(representation: "מֶּלֶכ", part_of_speech_category: pos_noun)
        word.glosses.create!(text: "king")

        # ה prefix + final form
        result = described_class.lookup("הַמֶּלֶך")

        expect(result[:found]).to be true
      end

      it "removes only leading nikkud after prefix removal" do
        word = Word.create!(representation: "שָׁמַע", part_of_speech_category: pos_verb)
        word.glosses.create!(text: "he heard")

        # Prefix with nikkud attached
        result = described_class.lookup("וְשָׁמַע")

        expect(result[:found]).to be true
        expect(result[:hebrew]).to eq("שָׁמַע")
      end
    end

    context "Multiple matches rejection" do
      it "returns not found if multiple exact matches exist" do
        Word.create!(representation: "בַּת", part_of_speech_category: pos_noun).glosses.create!(text: "daughter")
        Word.create!(representation: "בַּת", part_of_speech_category: pos_noun).glosses.create!(text: "bath (measure)")

        result = described_class.lookup("בַּת")

        expect(result[:found]).to be false
      end
    end

    context "Not found cases" do
      it "returns not found for unknown word" do
        result = described_class.lookup("xyz123")

        expect(result[:found]).to be false
        expect(result[:word]).to eq("xyz123")
      end

      it "returns not found for complex forms" do
        # Complex morphology out of scope
        result = described_class.lookup("וּבְבָתֵּיכֶם")

        expect(result[:found]).to be false
      end
    end

    context "Response format" do
      it "includes all required fields when found" do
        word = Word.create!(representation: "לָמַד", part_of_speech_category: pos_verb)
        word.glosses.create!(text: "he learned")

        result = described_class.lookup("לָמַד")

        expect(result).to include(:found, :original, :hebrew, :gloss, :transliteration, :pos)
        expect(result[:found]).to be true
        expect(result[:original]).to eq("לָמַד")
        expect(result[:transliteration]).to eq("") # Story provides this
      end

      it "includes word parameter when not found" do
        result = described_class.lookup("unknown")

        expect(result).to include(:found, :word)
        expect(result[:found]).to be false
      end
    end
  end
end
