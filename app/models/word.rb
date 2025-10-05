class Word < ApplicationRecord
  # Self-referential associations for lexeme/form relationships
  belongs_to :lexeme, class_name: "Word", optional: true
  has_many :forms, class_name: "Word", foreign_key: :lexeme_id, dependent: :nullify

  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy

  belongs_to :part_of_speech_category, optional: true
  belongs_to :gender, optional: true
  belongs_to :verb_form, optional: true

  # JSONB store accessors for form_metadata
  store_accessor :form_metadata,
    # Import fields
    :pos_type,            # "Lexical Category", "Functional Category", "Other/Base"
    :lesson_introduced,   # Lesson number
    :function,            # Functional description

    # Verb fields
    :root,                # 3-consonant root (e.g., "למד")
    :binyan,              # qal, niphal, piel, pual, hiphil, hophal, hitpael
    :aspect,              # perfective, imperfective, imperative, jussive, etc.
    :conjugation,         # 3MS, 1CS, etc. (person+gender+number combined)
    :person,              # 1, 2, 3
    :weakness,            # 1-Nun, 3-He, 2-Vav (Hollow), etc.

    # Noun/Adjective fields
    :number,              # singular, plural, dual, form only plural
    :status,              # absolute, construct, determined
    :specific_type,       # collective, epicene, uncountable, irregular plural
    :definiteness_agreement, # For adjectives

    # Participle fields
    :verbal_root,         # Link to base verb

    # Pronoun fields
    :sub_type,            # Demonstrative, Personal, Interrogative, etc.

    # Functional word fields
    :grammatical_role,    # inseparable prefix, object marker, etc.

    # General fields
    :gender_meta,         # masculine, feminine, common (used across nouns, adjectives, pronouns, etc.)
    :category,            # descriptive, cardinal number, ordinal number, etc.
    :variant_type,        # plene, defective, modern, ancient
    :notes,               # Additional notes
    :name,                # Letter name (for consonants)
    :transliteration      # Romanization

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
  scope :word_forms, -> { where.not(lexeme_id: nil) }
  scope :dictionary_entries, -> {
    where(lexeme_id: nil).select { |w| w.is_dictionary_entry? }
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

  # Determines if this word should appear in dictionary listings
  # Based on POS category and metadata (not a database field)
  def is_dictionary_entry?
    # Forms are never dictionary entries
    return false if lexeme_id.present?

    # Determine based on POS category and metadata
    case part_of_speech_category&.name
    when "Verb"
      # Only 3MS (3rd person masculine singular) is dictionary entry
      form_metadata["conjugation"] == "3MS"

    when "Noun", "Proper Noun"
      # Only singular forms in absolute state (or unspecified status) are dictionary entries
      # Construct state nouns are not dictionary entries
      form_metadata["number"] == "singular" && form_metadata["status"] != "construct"

    when "Adjective"
      # Only masculine singular is dictionary entry
      form_metadata["gender"] == "masculine" && form_metadata["number"] == "singular"

    when "Participle"
      # Only masculine singular active is dictionary entry
      form_metadata["gender"] == "masculine" &&
        form_metadata["number"] == "singular" &&
        form_metadata["aspect"] == "active"

    when "Pronoun", "Interrogative Pronoun"
      # All pronouns are dictionary entries (each is distinct)
      true

    when "Preposition", "Conjunction", "Article", "Particle", "Adverb/Particle"
      # All functional words are dictionary entries
      true

    when "Consonant"
      # All consonants are dictionary entries
      true

    else
      # Default: show in dictionary if no lexeme_id
      true
    end
  end

  # Returns the parent word (lexeme) if this is a form, otherwise returns self
  def parent_word
    lexeme_id.present? ? lexeme : self
  end

  # Describes the grammatical form of this word based on metadata
  # Returns "Dictionary entry" for dictionary entries, or a descriptive string for forms
  def form_description
    return "Dictionary entry" if is_dictionary_entry?

    # Describe the form based on metadata
    if form_metadata["conjugation"].present?
      # Verb conjugation
      parts = [
        form_metadata["binyan"],
        form_metadata["aspect"],
        form_metadata["conjugation"]
      ].compact
      parts.join(" ")
    elsif form_metadata["number"] == "plural"
      # Plural noun/adjective
      "plural #{form_metadata["status"] || "form"}"
    elsif form_metadata["status"] == "construct"
      # Construct state
      "construct #{form_metadata["number"] || "form"}"
    else
      # Generic description
      "variant"
    end
  end

  # Returns the full display name with form description for non-dictionary entries
  # Example: "לָמַדְתִּי (qal perfective 1CS)" or "גָּדוֹל" (dictionary entry)
  def full_display_name
    parts = [ representation ]
    parts << "(#{form_description})" unless is_dictionary_entry?
    parts.join(" ")
  end

  private

  def update_pos_display
    self.pos_display = formatted_pos
  end
end
