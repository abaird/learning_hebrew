require 'rails_helper'

RSpec.describe DictionaryImportParser do
  describe '#parse' do
    it 'parses a single word with one gloss' do
      content = <<~TXT
        שָׁלוֹם
        peace
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'שָׁלוֹם', glosses: [ 'peace' ] }
      ])
    end

    it 'parses a single word with multiple glosses' do
      content = <<~TXT
        שָׁלוֹם
        peace
        hello
        goodbye
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'שָׁלוֹם', glosses: [ 'peace', 'hello', 'goodbye' ] }
      ])
    end

    it 'parses multiple words with glosses' do
      content = <<~TXT
        אֱלֹהִים
        God
        gods
        ---
        שָׁלוֹם
        peace
        hello
        ---
        תּוֹרָה
        Torah
        instruction
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'אֱלֹהִים', glosses: [ 'God', 'gods' ] },
        { representation: 'שָׁלוֹם', glosses: [ 'peace', 'hello' ] },
        { representation: 'תּוֹרָה', glosses: [ 'Torah', 'instruction' ] }
      ])
    end

    it 'handles words with nikkud correctly' do
      content = <<~TXT
        דָּבָר
        word
        thing
        ---
        דְּבַר
        spoke
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result.length).to eq(2)
      expect(result[0][:representation]).to eq('דָּבָר')
      expect(result[1][:representation]).to eq('דְּבַר')
      # These should be treated as different words
      expect(result[0][:representation]).not_to eq(result[1][:representation])
    end

    it 'strips whitespace from words and glosses' do
      content = <<~TXT
          שָׁלוֹם
          peace
          hello
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'שָׁלוֹם', glosses: [ 'peace', 'hello' ] }
      ])
    end

    it 'ignores empty lines between glosses' do
      content = <<~TXT
        שָׁלוֹם
        peace

        hello
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'שָׁלוֹם', glosses: [ 'peace', 'hello' ] }
      ])
    end

    it 'handles trailing separator without content' do
      content = <<~TXT
        שָׁלוֹם
        peace
        ---
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        { representation: 'שָׁלוֹם', glosses: [ 'peace' ] }
      ])
    end

    it 'raises error if section has no word' do
      content = <<~TXT
        peace
        hello
        ---
      TXT

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must start with a Hebrew word/)
    end

    it 'raises error if section has no glosses' do
      content = <<~TXT
        שָׁלוֹם
        ---
      TXT

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must have at least one gloss/)
    end

    it 'raises error if word contains only whitespace' do
      content = <<~TXT

        peace
        ---
      TXT

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must start with a Hebrew word/)
    end

    it 'handles empty content' do
      content = ""

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([])
    end

    it 'preserves Hebrew character order and nikkud marks' do
      # Hebrew word with nikkud: shin-lamed-vav-mem with specific vowel marks
      content = <<~TXT
        שָׁלוֹם
        peace
        ---
      TXT

      result = DictionaryImportParser.new(content).parse

      # Check that the exact Unicode sequence is preserved
      hebrew_word = result[0][:representation]
      expect(hebrew_word.bytes.length).to be > hebrew_word.chars.length # Has combining marks
      expect(hebrew_word).to eq('שָׁלוֹם')
    end
  end
end
