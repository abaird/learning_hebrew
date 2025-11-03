#!/usr/bin/env ruby
# Test Hebrew normalization with cantillation mark stripping

require 'digest'

# Unicode ranges for Hebrew marks
HEBREW_CANTILLATION = (0x0591..0x05AF).to_a.map { |cp| [ cp ].pack('U') }.join
HEBREW_VOWEL_POINTS = (0x05B0..0x05BD).to_a.map { |cp| [ cp ].pack('U') }.join +
                      "\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7"  # Additional vowel marks
HEBREW_DAGESH_MAPPIQ = "\u05BC"  # Dagesh/Mappiq (keep this - it's pronunciation)

def hash_hebrew_original(text)
  # Original: just normalize
  normalized = text.unicode_normalize(:nfc)
  Digest::SHA256.hexdigest(normalized.encode('UTF-8'))[0...12]
end

def hash_hebrew_strip_cantillation(text)
  # Strip cantillation marks (0x0591-0x05AF) before hashing
  # Keep vowel points and dagesh (they affect pronunciation)
  normalized = text.unicode_normalize(:nfc)

  # Remove cantillation marks (ta'amim)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')

  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

def hash_hebrew_strip_all_nikkud(text)
  # Strip ALL marks (cantillation + vowels + dagesh)
  # Use this if you want bare consonants only
  normalized = text.unicode_normalize(:nfc)

  # Remove all Hebrew marks (0x0591-0x05C7)
  cleaned = normalized.gsub(/[\u0591-\u05C7]/, '')

  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

def show_codepoints(text)
  text.codepoints.map { |cp| "U+%04X" % cp }.join(' ')
end

def analyze_text(text)
  puts "Text: #{text}"
  puts "Codepoints: #{show_codepoints(text)}"

  codepoint_details = text.codepoints.map do |cp|
    case cp
    when 0x0591..0x05AF
      "  U+%04X - CANTILLATION mark" % cp
    when 0x05B0..0x05BD, 0x05BF, 0x05C1, 0x05C2, 0x05C4, 0x05C5, 0x05C7
      "  U+%04X - VOWEL point" % cp
    when 0x05BC
      "  U+%04X - DAGESH/MAPPIQ" % cp
    when 0x05D0..0x05EA
      "  U+%04X - Hebrew letter" % cp
    else
      "  U+%04X - Other" % cp
    end
  end

  puts codepoint_details.join("\n")
end

# Test cases
puts "=" * 70
puts "HEBREW CANTILLATION MARK STRIPPING TEST"
puts "=" * 70
puts

# Example 1: Word with cantillation vs without
puts "Example 1: אֶ֫רֶץ (earth) with accent vs אֶרֶץ without accent"
puts "-" * 70

text_with_accent = "אֶ֫רֶץ"    # eretz with meteg (0x05AB)
text_without_accent = "אֶרֶץ"  # eretz without accent

puts "\nWith cantillation:"
analyze_text(text_with_accent)
puts

puts "Without cantillation:"
analyze_text(text_without_accent)
puts

puts "\nHashing results:"
puts "Original hash (with accent):    #{hash_hebrew_original(text_with_accent)}"
puts "Original hash (no accent):      #{hash_hebrew_original(text_without_accent)}"
puts "Match? #{hash_hebrew_original(text_with_accent) == hash_hebrew_original(text_without_accent) ? '✓' : '✗'}"
puts

puts "Strip cantillation (with):      #{hash_hebrew_strip_cantillation(text_with_accent)}"
puts "Strip cantillation (no accent): #{hash_hebrew_strip_cantillation(text_without_accent)}"
puts "Match? #{hash_hebrew_strip_cantillation(text_with_accent) == hash_hebrew_strip_cantillation(text_without_accent) ? '✓ YES' : '✗ NO'}"
puts

# Example 2: Multiple cantillation marks
puts "\n" + "=" * 70
puts "Example 2: Genesis 1:1 snippet with multiple cantillation marks"
puts "-" * 70

text_full = "בְּרֵאשִׁ֖ית"     # Bereshit with cantillation
text_clean = "בְּרֵאשִׁית"     # Bereshit without cantillation

puts "\nWith cantillation:"
analyze_text(text_full)
puts

puts "Without cantillation:"
analyze_text(text_clean)
puts

puts "\nHashing results:"
puts "Original (with marks):    #{hash_hebrew_original(text_full)}"
puts "Original (clean):         #{hash_hebrew_original(text_clean)}"
puts "Match? #{hash_hebrew_original(text_full) == hash_hebrew_original(text_clean) ? '✓' : '✗'}"
puts

puts "Strip cantillation (with): #{hash_hebrew_strip_cantillation(text_full)}"
puts "Strip cantillation (clean): #{hash_hebrew_strip_cantillation(text_clean)}"
puts "Match? #{hash_hebrew_strip_cantillation(text_full) == hash_hebrew_strip_cantillation(text_clean) ? '✓ YES' : '✗ NO'}"
puts

# Example 3: Show what gets stripped
puts "\n" + "=" * 70
puts "Example 3: What gets stripped vs kept"
puts "-" * 70

test_word = "דָּבָ֥ר"  # davar with cantillation

puts "\nOriginal: #{test_word}"
puts "Codepoints: #{show_codepoints(test_word)}"
puts

stripped_cantillation = test_word.gsub(/[\u0591-\u05AF]/, '')
puts "After stripping cantillation: #{stripped_cantillation}"
puts "Codepoints: #{show_codepoints(stripped_cantillation)}"
puts "(Keeps: vowels, dagesh)"
puts

stripped_all = test_word.gsub(/[\u0591-\u05C7]/, '')
puts "After stripping ALL marks: #{stripped_all}"
puts "Codepoints: #{show_codepoints(stripped_all)}"
puts "(Keeps: consonants only)"
puts

# Comparison table
puts "\n" + "=" * 70
puts "RECOMMENDED APPROACH"
puts "=" * 70
puts
puts "Strip cantillation marks (0x0591-0x05AF) ONLY"
puts "Keep vowel points and dagesh (they affect pronunciation)"
puts
puts "Why?"
puts "  - Cantillation marks are musical notation (don't affect pronunciation)"
puts "  - Vowel points DO affect pronunciation:"
puts "    בַּת (bat - daughter) vs בֵּית (beit - house)"
puts "  - Dagesh affects pronunciation:"
puts "    בּ (b with dagesh) vs ב (v without dagesh)"
puts

# Unicode ranges reference
puts "\n" + "=" * 70
puts "HEBREW UNICODE RANGES REFERENCE"
puts "=" * 70
puts
puts "Cantillation marks (STRIP):  U+0591 - U+05AF"
puts "  Examples: etnahta, segol, zaqef, pashta, etc."
puts
puts "Vowel points (KEEP):         U+05B0 - U+05BD, U+05BF, U+05C1, U+05C2"
puts "  Examples: shva, patach, qamats, segol, etc."
puts
puts "Dagesh/Mappiq (KEEP):        U+05BC"
puts "  Affects consonant pronunciation"
puts
puts "Hebrew letters:              U+05D0 - U+05EA"
puts "  Alef through Tav"
puts

puts "=" * 70
puts "FINAL RECOMMENDATION"
puts "=" * 70
puts
puts "Use: hash_hebrew_strip_cantillation()"
puts
puts "This ensures:"
puts "  ✓ Words with/without cantillation marks hash the same"
puts "  ✓ Vowel points are preserved (pronunciation matters)"
puts "  ✓ Dagesh is preserved (pronunciation matters)"
puts "  ✓ Compatible with vocalized Hebrew learning materials"
