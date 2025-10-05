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

  describe '#parse JSON format' do
    it 'parses a single JSON entry with metadata' do
      content = <<~JSON
        [
          {
            "word": "לָמַד",
            "glosses": ["to learn", "to study"],
            "pos": "Verb",
            "pos_detail": {
              "binyan": "qal",
              "conjugation": "3MS"
            }
          }
        ]
      JSON

      result = DictionaryImportParser.new(content).parse

      expect(result).to eq([
        {
          representation: 'לָמַד',
          glosses: [ 'to learn', 'to study' ],
          pos: 'Verb',
          form_metadata: {
            'binyan' => 'qal',
            'conjugation' => '3MS'
          },
          lexeme_of_hint: nil,
          pronunciation_url: nil,
          picture_url: nil,
          mnemonic: nil
        }
      ])
    end

    it 'parses JSON with all metadata fields merged' do
      content = <<~JSON
        [
          {
            "word": "בַּ֫יִת",
            "lesson_introduced": 5,
            "function": "a house",
            "glosses": ["house", "temple"],
            "pos_type": "Lexical Category",
            "pos": "Noun",
            "pos_detail": {
              "gender": "masculine",
              "number": "singular",
              "status": "absolute"
            }
          }
        ]
      JSON

      result = DictionaryImportParser.new(content).parse

      expect(result.first[:form_metadata]).to eq({
        'gender' => 'masculine',
        'number' => 'singular',
        'status' => 'absolute',
        'pos_type' => 'Lexical Category',
        'lesson_introduced' => 5,
        'function' => 'a house'
      })
    end

    it 'parses JSON with lexeme_of_hint for linked words' do
      content = <<~JSON
        [
          {
            "word": "בָּתִּים",
            "glosses": ["houses"],
            "pos": "Noun",
            "lexeme_of_hint": "בַּ֫יִת",
            "pos_detail": {
              "number": "plural"
            }
          }
        ]
      JSON

      result = DictionaryImportParser.new(content).parse

      expect(result.first[:lexeme_of_hint]).to eq('בַּ֫יִת')
    end

    it 'parses JSON with optional fields' do
      content = <<~JSON
        [
          {
            "word": "שָׁלוֹם",
            "glosses": ["peace"],
            "pos": "Noun",
            "pos_detail": {},
            "pronunciation_url": "https://example.com/shalom.mp3",
            "picture_url": "https://example.com/shalom.jpg",
            "mnemonic": "Think of salaam"
          }
        ]
      JSON

      result = DictionaryImportParser.new(content).parse

      expect(result.first[:pronunciation_url]).to eq('https://example.com/shalom.mp3')
      expect(result.first[:picture_url]).to eq('https://example.com/shalom.jpg')
      expect(result.first[:mnemonic]).to eq('Think of salaam')
    end

    it 'raises error if JSON is missing word field' do
      content = <<~JSON
        [
          {
            "glosses": ["test"],
            "pos": "Noun"
          }
        ]
      JSON

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must have a 'word' field/)
    end

    it 'raises error if JSON is missing glosses field' do
      content = <<~JSON
        [
          {
            "word": "שָׁלוֹם",
            "pos": "Noun"
          }
        ]
      JSON

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must have a non-empty 'glosses' array/)
    end

    it 'raises error if JSON is missing pos field' do
      content = <<~JSON
        [
          {
            "word": "שָׁלוֹם",
            "glosses": ["peace"]
          }
        ]
      JSON

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /must have a 'pos'/)
    end

    it 'raises error if JSON is malformed' do
      content = '{ invalid json }'

      parser = DictionaryImportParser.new(content)
      expect { parser.parse }.to raise_error(DictionaryImportParser::ParseError, /Invalid JSON format/)
    end

    it 'handles single JSON object (not array)' do
      content = <<~JSON
        {
          "word": "שָׁלוֹם",
          "glosses": ["peace"],
          "pos": "Noun",
          "pos_detail": {}
        }
      JSON

      result = DictionaryImportParser.new(content).parse

      expect(result.length).to eq(1)
      expect(result.first[:representation]).to eq('שָׁלוֹם')
    end
  end
end
