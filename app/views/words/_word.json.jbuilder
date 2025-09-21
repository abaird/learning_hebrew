json.extract! word, :id, :representation, :part_of_speech, :mnemonic, :pronunciation_url, :picture_url, :deck_id, :created_at, :updated_at
json.url word_url(word, format: :json)
