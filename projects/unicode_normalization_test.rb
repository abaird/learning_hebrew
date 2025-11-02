#!/usr/bin/env ruby
# Test Unicode normalization behavior with Hebrew nikkud

require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  Digest::SHA256.hexdigest(normalized.encode('UTF-8'))[0...12]
end

def show_codepoints(text)
  text.codepoints.map { |cp| "U+%04X" % cp }.join(' ')
end

# Test case: bet + dagesh + patach vs bet + patach + dagesh
text1 = "\u05D1\u05BC\u05B7"  # bet + dagesh + patach
text2 = "\u05D1\u05B7\u05BC"  # bet + patach + dagesh

puts "Original Order Test:"
puts "=" * 60
puts "Text 1: #{text1.inspect}"
puts "Codepoints: #{show_codepoints(text1)}"
puts "Visual: #{text1}"
puts

puts "Text 2: #{text2.inspect}"
puts "Codepoints: #{show_codepoints(text2)}"
puts "Visual: #{text2}"
puts

# Normalize both
norm1 = text1.unicode_normalize(:nfc)
norm2 = text2.unicode_normalize(:nfc)

puts "\nAfter NFC Normalization:"
puts "=" * 60
puts "Normalized 1: #{norm1.inspect}"
puts "Codepoints: #{show_codepoints(norm1)}"
puts

puts "Normalized 2: #{norm2.inspect}"
puts "Codepoints: #{show_codepoints(norm2)}"
puts

puts "\nAre they equal? #{norm1 == norm2}"
puts

# Hash them
hash1 = hash_hebrew(text1)
hash2 = hash_hebrew(text2)

puts "\nHashes:"
puts "=" * 60
puts "Hash 1: #{hash1}"
puts "Hash 2: #{hash2}"
puts "Hashes equal? #{hash1 == hash2}"
puts

# Show the canonical combining classes
puts "\nCanonical Combining Classes:"
puts "=" * 60
puts "Bet (בּ) - U+05D1: base character (class 0)"
puts "Dagesh (◌ּ) - U+05BC: class 21 (point below)"
puts "Patach (◌ַ) - U+05B7: class 25 (point below)"
puts "\nUnicode normalizes to canonical order: Dagesh (21) before Patach (25)"
puts

# More examples
puts "\nMore Examples:"
puts "=" * 60

examples = [
  ["\u05E9\u05C1\u05B0", "\u05E9\u05B0\u05C1", "shin + shin-dot + shva vs shin + shva + shin-dot"],
  ["\u05D1\u05BC\u05B0", "\u05D1\u05B0\u05BC", "bet + dagesh + shva vs bet + shva + dagesh"],
  ["\u05DB\u05BC\u05B8", "\u05DB\u05B8\u05BC", "kaf + dagesh + qamats vs kaf + qamats + dagesh"]
]

examples.each do |text_a, text_b, desc|
  hash_a = hash_hebrew(text_a)
  hash_b = hash_hebrew(text_b)

  puts "\n#{desc}"
  puts "  Order 1: #{text_a} (#{show_codepoints(text_a)})"
  puts "  Order 2: #{text_b} (#{show_codepoints(text_b)})"
  puts "  Hash A: #{hash_a}"
  puts "  Hash B: #{hash_b}"
  puts "  Equal? #{hash_a == hash_b ? '✓ YES' : '✗ NO'}"
end

puts "\n" + "=" * 60
puts "CONCLUSION:"
puts "=" * 60
puts "Unicode NFC normalization automatically reorders combining marks"
puts "according to their canonical combining class (CCC)."
puts ""
puts "This is a GOOD thing for our use case!"
puts "It means different typing orders produce the same hash."
puts ""
puts "Hebrew combining classes (partial list):"
puts "  10 = Above (points/accents above letter)"
puts "  11 = Above (additional)"
puts "  14-16 = Above right"
puts "  18 = Below left"
puts "  19 = Below"
puts "  20 = Below"
puts "  21 = Below (Dagesh, Mappiq)"
puts "  22 = Below right"
puts "  23 = Below right"
puts "  24 = Above left"
puts "  25 = Below (Patach)"
puts "  26 = Below (Qamats)"
puts ""
puts "Lower class numbers come FIRST in canonical order."
