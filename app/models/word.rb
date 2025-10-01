class Word < ApplicationRecord
  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy

  validates :representation, presence: true
  validates :part_of_speech, presence: true

  # Hebrew alphabet order for sorting
  HEBREW_ALPHABET = %w[א ב ג ד ה ו ז ח ט י כ ך ל מ ם נ ן ס ע פ ף צ ץ ק ר ש ת]

  scope :alphabetically, -> {
    all.sort_by { |word| hebrew_sort_key(word.representation) }
  }

  def self.hebrew_sort_key(hebrew_text)
    return [ Float::INFINITY ] if hebrew_text.blank?

    hebrew_text.chars.map do |char|
      index = HEBREW_ALPHABET.index(char)
      index || Float::INFINITY
    end
  end
end
