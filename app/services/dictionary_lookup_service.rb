class DictionaryLookupService
  # Common Hebrew prefixes
  PREFIXES = %w[ה ו ב כ ל מ ש].freeze

  # Final form mappings
  FINAL_FORMS = {
    "ך" => "כ",
    "ם" => "מ",
    "ן" => "נ",
    "ף" => "פ",
    "ץ" => "צ"
  }.freeze

  def self.lookup(word)
    # Tier 1: Exact match (including all nikkud)
    match = find_exact_match(word)
    return format_result(match, word) if match

    # Tier 2: Final form normalization (preserve nikkud)
    match = try_final_form_normalization(word)
    return format_result(match, word) if match

    # Tier 3: Prefix removal (strip only prefix's nikkud)
    match = try_with_prefix_removal(word)
    return format_result(match, word) if match

    # Not found
    { found: false, word: word }
  end

  def self.find_exact_match(word)
    # Direct exact match on representation field (includes nikkud)
    matches = Word.where(representation: word)
                  .includes(:glosses, :part_of_speech_category)
                  .limit(2) # Get 2 to check if there are multiples

    # Only return if exactly ONE match (confidence requirement)
    matches.count == 1 ? matches.first : nil
  end

  def self.try_final_form_normalization(word)
    # Convert final forms to regular forms, preserving all nikkud
    normalized = word.chars.map { |char| FINAL_FORMS[char] || char }.join

    # Skip if no change was made
    return nil if normalized == word

    find_exact_match(normalized)
  end

  def self.try_with_prefix_removal(word)
    PREFIXES.each do |prefix|
      next unless word.start_with?(prefix)

      # Remove prefix (first character)
      without_prefix = word[1..]

      # Remove ONLY nikkud directly attached to the removed prefix
      # This means removing leading nikkud marks (vowels/cantillation)
      without_prefix = remove_leading_nikkud(without_prefix)

      # Try exact match
      match = find_exact_match(without_prefix)
      return match if match

      # Also try final form normalization on the result
      normalized = without_prefix.chars.map { |char| FINAL_FORMS[char] || char }.join
      if normalized != without_prefix
        match = find_exact_match(normalized)
        return match if match
      end
    end

    nil
  end

  def self.remove_leading_nikkud(text)
    # Remove ONLY leading nikkud (vowel points and cantillation marks)
    # Unicode ranges: U+0591-05AF (cantillation), U+05B0-05BD, U+05BF-05C2, U+05C4-05C5, U+05C7 (vowels)
    # This preserves nikkud on other letters
    text.sub(/^[\u0591-\u05AF\u05B0-\u05BD\u05BF-\u05C2\u05C4\u05C5\u05C7]+/, "")
  end

  def self.format_result(word, original_word)
    {
      found: true,
      original: original_word,
      hebrew: word.representation,
      gloss: word.glosses.map(&:text).join(", "), # Show ALL glosses
      transliteration: "", # Story provides transliteration, not dictionary
      pos: word.part_of_speech_category&.name || ""
    }
  end

  private_class_method :find_exact_match, :try_final_form_normalization,
                       :try_with_prefix_removal, :remove_leading_nikkud, :format_result
end
