json.extract! word, :id, :representation, :part_of_speech, :mnemonic, :pronunciation_url, :picture_url, :created_at, :updated_at
json.decks word.decks, :id, :name
json.url word_url(word, format: :json)
