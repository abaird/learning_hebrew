class DictionaryImportParser
  class ParseError < StandardError; end

  SEPARATOR = "---"

  def initialize(content)
    @content = content
  end

  def parse
    return [] if @content.blank?

    sections = split_into_sections(@content)
    sections.map { |section| parse_section(section) }.compact
  end

  private

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
