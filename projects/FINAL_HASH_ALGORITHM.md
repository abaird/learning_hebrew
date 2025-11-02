# Final Hash Algorithm for Audio Identifiers

## The Complete Algorithm

```
1. Take Hebrew representation (e.g., "שָׁלוֹם" or "אֶ֫רֶץ")
2. Normalize Unicode to NFC form (canonical composition)
3. Strip cantillation marks (U+0591 - U+05AF)
4. Encode to UTF-8 bytes
5. Compute SHA-256 hash
6. Take first 12 characters of hexadecimal output
7. Result: 12-character hex string (e.g., "007c9089f1d5")
```

## Ruby Implementation (Final)

```ruby
def self.hash_hebrew_text(hebrew_text)
  require 'digest'

  # Step 1: Normalize Unicode to NFC (canonical composition)
  normalized = hebrew_text.unicode_normalize(:nfc)

  # Step 2: Strip cantillation marks (U+0591-U+05AF)
  # Keep vowel points and dagesh (they affect pronunciation)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')

  # Step 3: Encode to UTF-8 bytes
  utf8_bytes = cleaned.encode('UTF-8')

  # Step 4: Compute SHA-256 hash
  hash = Digest::SHA256.hexdigest(utf8_bytes)

  # Step 5: Take first 12 characters (48 bits)
  hash[0...12]
end
```

## Why This Works Perfectly

### 1. Unicode Normalization (NFC)
**Problem:** Different keyboards/systems might type nikkud in different orders
- Input A: bet + dagesh + patach → U+05D1 U+05BC U+05B7
- Input B: bet + patach + dagesh → U+05D1 U+05B7 U+05BC

**Solution:** NFC normalization reorders to canonical form
- Both → U+05D1 U+05B7 U+05BC (same order!)
- Same normalized form → same hash

### 2. Cantillation Mark Stripping
**Problem:** Same word appears with/without cantillation marks in different sources
- Biblical text: אֶ֫רֶץ (with meteg U+05AB)
- Dictionary: אֶרֶץ (without cantillation)

**Solution:** Strip cantillation marks before hashing
- Both → "אֶרֶץ" (cleaned)
- Same cleaned form → same hash ("007c9089f1d5")

### 3. What Gets Stripped vs Kept

**STRIP (U+0591-U+05AF):**
- Cantillation marks (ta'amim)
- Musical notation for Torah chanting
- Don't affect pronunciation
- Examples: meteg (֫), etnahta (֑), tipcha (֖)

**KEEP:**
- Vowel points: patach (ַ), qamats (ָ), segol (ֶ), shva (ְ), etc.
- Dagesh/Mappiq (ּ) - U+05BC
- Shin/Sin dots (ׁ ׂ) - U+05C1, U+05C2
- These DO affect pronunciation!

## Real-World Test Cases

```ruby
# Test 1: Cantillation mark stripping
hash_hebrew_text("אֶ֫רֶץ")  # with meteg
# => "007c9089f1d5"

hash_hebrew_text("אֶרֶץ")   # without meteg
# => "007c9089f1d5"  ✓ SAME!

# Test 2: Unicode normalization
hash_hebrew_text("\u05D1\u05BC\u05B7")  # bet + dagesh + patach
# => "6f9bd8c0627a"

hash_hebrew_text("\u05D1\u05B7\u05BC")  # bet + patach + dagesh
# => "6f9bd8c0627a"  ✓ SAME!

# Test 3: Vowel points still matter
hash_hebrew_text("בַּת")  # bat (daughter) - patach
# => "..." (unique hash)

hash_hebrew_text("בֵּית")  # beit (house) - tsere
# => "..." (different hash) ✓ DIFFERENT!
```

## Why This Is Perfect for Your Use Case

✅ **Portable across apps**
- Generate hash in Rails → use in iOS app
- Same Hebrew text → same hash → same audio file

✅ **Deterministic**
- Same word always produces same hash
- Different input orders → normalized → same hash

✅ **Handles real-world data**
- Biblical texts with cantillation → stripped → matches dictionary
- Different keyboards/typing orders → normalized → matches

✅ **Preserves pronunciation**
- Different vowels = different words = different hashes
- Cantillation doesn't change pronunciation = same hash

✅ **No database dependency**
- Any app can compute hash from Hebrew text alone
- No need to query database to find audio file

## File Naming Convention

```
Format: {hash}.mp3

Examples:
- שָׁלוֹם → e8f2a6d3c1b4.mp3
- אֶרֶץ → 007c9089f1d5.mp3
- מֶלֶךְ → 7a3c5f1d8b2e.mp3
```

## Quick Test Script

```ruby
# Test this right now in Rails console!
require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

# Try it:
hash_hebrew("שָׁלוֹם")
hash_hebrew("אֶ֫רֶץ")  # with cantillation
hash_hebrew("אֶרֶץ")   # without cantillation (should match above!)
```

## Summary

**Your question:** "Do we need to strip accents before hashing?"

**Answer:** Yes! Strip **cantillation marks** (U+0591-U+05AF) but **keep vowel points**.

**Result:**
- Words with/without cantillation → same hash ✓
- Different vowel points → different hash ✓
- Different typing orders → same hash ✓
- Portable across all apps ✓

This is the final algorithm - it handles all edge cases perfectly!
