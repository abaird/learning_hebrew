class Word < ApplicationRecord
  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy

  belongs_to :part_of_speech_category, optional: true
  belongs_to :gender, optional: true
  belongs_to :verb_form, optional: true

  validates :representation, presence: true

  before_save :update_pos_display

  # Hebrew alphabet order for sorting (consonants)
  HEBREW_ALPHABET = %w[א ב ג ד ה ו ז ח ט י כ ך ל מ ם נ ן ס ע פ ף צ ץ ק ר ש ת]

  # Hebrew vowel marks (nikkud) in alphabetical order: a, e, i, o, u
  HEBREW_VOWELS = {
    "\u05B7" => 1,  # Patach - "a"
    "\u05B8" => 2,  # Qamats - "a" (long)
    "\u05B6" => 3,  # Segol - "e"
    "\u05B5" => 4,  # Tsere - "e" (long)
    "\u05B4" => 5,  # Hireq - "i"
    "\u05B9" => 6,  # Holam - "o"
    "\u05BB" => 7,  # Qubuts - "u"
    "\u05C1" => 8,  # Shin dot
    "\u05C2" => 9,  # Sin dot
    "\u05BC" => 10  # Dagesh
  }

  scope :alphabetically, -> {
    all.sort_by { |word| hebrew_sort_key(word.representation) }
  }

  def self.hebrew_sort_key(hebrew_text)
    return [ Float::INFINITY ] if hebrew_text.blank?

    result = []
    hebrew_text.each_char do |char|
      if HEBREW_ALPHABET.include?(char)
        # Consonant: use its position in alphabet
        result << [ HEBREW_ALPHABET.index(char), 0 ]
      elsif HEBREW_VOWELS[char]
        # Vowel mark: append to previous consonant as secondary sort key
        if result.any?
          result.last[1] = HEBREW_VOWELS[char]
        end
      end
      # Ignore other characters (punctuation, etc.)
    end

    result.empty? ? [ [ Float::INFINITY, 0 ] ] : result
  end

  # Returns formatted glosses as numbered list: "1) peace, 2) hello"
  def formatted_glosses
    glosses.map.with_index { |gloss, i| "#{i + 1}) #{gloss.text}" }.join(", ")
  end

  # Returns formatted part of speech: "n.masc", "v.inf", etc.
  def formatted_pos
    return "" unless part_of_speech_category.present?

    parts = [ part_of_speech_category.abbrev ]
    parts << gender.abbrev if gender.present?
    parts << verb_form.abbrev if verb_form.present?
    parts.join(".")
  end

  private

  def update_pos_display
    self.pos_display = formatted_pos
  end
end
