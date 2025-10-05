class DictionaryImportParser
  class ParseError < StandardError; end

  SEPARATOR = "---"

  def initialize(content)
    @content = content
  end

  def parse
    return [] if @content.blank?

    # Detect format (JSON or text)
    if json_format?
      parse_json
    else
      parse_text
    end
  end

  private

  def json_format?
    # Check if content starts with [ or { (after stripping whitespace)
    @content.strip.start_with?("[", "{")
  end

  def parse_json
    data = JSON.parse(@content)
    # Ensure it's an array
    data = [ data ] unless data.is_a?(Array)

    data.map { |entry| parse_json_entry(entry) }
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON format: #{e.message}"
  end

  def parse_json_entry(entry)
    # Validate required fields
    validate_json_entry!(entry)

    # Build metadata by merging pos_detail with other metadata fields
    metadata = (entry["pos_detail"] || {}).dup
    metadata["pos_type"] = entry["pos_type"] if entry["pos_type"].present?
    metadata["lesson_introduced"] = entry["lesson_introduced"] if entry["lesson_introduced"].present?
    metadata["function"] = entry["function"] if entry["function"].present?

    {
      representation: entry["word"],
      glosses: entry["glosses"],
      pos: entry["pos"],
      form_metadata: metadata,
      lexeme_of_hint: entry["lexeme_of_hint"],
      pronunciation_url: entry["pronunciation_url"],
      picture_url: entry["picture_url"],
      mnemonic: entry["mnemonic"]
    }
  end

  def validate_json_entry!(entry)
    if entry["word"].blank?
      raise ParseError, "Each entry must have a 'word' field"
    end

    if entry["glosses"].blank? || !entry["glosses"].is_a?(Array) || entry["glosses"].empty?
      raise ParseError, "Each entry must have a non-empty 'glosses' array"
    end

    if entry["pos"].blank?
      raise ParseError, "Each entry must have a 'pos' (part of speech) field"
    end
  end

  def parse_text
    sections = split_into_sections(@content)
    sections.map { |section| parse_section(section) }.compact
  end

  def split_into_sections(content)
    # Split by separator and filter out empty sections
    content.split(SEPARATOR).map(&:strip).reject(&:blank?)
  end

  def parse_section(section)
    lines = section.lines.map(&:strip).reject(&:blank?)

    return nil if lines.empty?

    word = lines.first
    glosses = lines[1..]

    validate_section!(word, glosses)

    {
      representation: word,
      glosses: glosses
    }
  end

  def validate_section!(word, glosses)
    # Check if first line appears to be Hebrew (has Hebrew characters or is blank)
    # We allow any content in the first line but it should not be blank
    if word.blank? || !contains_hebrew?(word)
      raise ParseError, "Each section must start with a Hebrew word"
    end

    if glosses.empty?
      raise ParseError, "Each word must have at least one gloss"
    end
  end

  def contains_hebrew?(text)
    # Check for Hebrew characters (including with nikkud)
    # Hebrew Unicode range: \u0590-\u05FF (includes letters and nikkud)
    text.match?(/[\u0590-\u05FF]/)
  end
end
