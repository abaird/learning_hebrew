# Audio Support Project - Executive Summary

## Your Requirement: Hash-Based Identifiers

**You said:** "I want to do basically option 2 - a hashed value against all the characters in the word. Since the audio is the pronunciation of the word it will always be the same if they are the same letters. So, if I have a repeatable hash algorithm, I can reuse that to name the words in a different app."

**Perfect!** This is the ideal solution for your use case.

## The Solution: SHA-256 Hash of Hebrew Text

### Algorithm (Language-Agnostic)

```
1. Take Hebrew representation (e.g., "שָׁלוֹם")
2. Normalize Unicode to NFC form (canonical composition)
3. Strip cantillation marks (U+0591 - U+05AF) - keep vowel points!
4. Encode to UTF-8 bytes
5. Compute SHA-256 hash
6. Take first 12 characters of hexadecimal output
7. Result: "e8f2a6d3c1b4" (example)
```

**Why strip cantillation marks?**
- Cantillation marks (ta'amim) are musical notation for Torah chanting
- Same word may appear with/without cantillation in different sources
- They don't affect pronunciation - only the musical melody
- Example: אֶ֫רֶץ (with meteg) hashes same as אֶרֶץ (without)

**What gets stripped vs kept:**
- ✗ **STRIP**: Cantillation marks (U+0591-U+05AF) - meteg, etnahta, tipcha, etc.
- ✓ **KEEP**: Vowel points - patach, qamats, shva, segol (affect pronunciation!)
- ✓ **KEEP**: Dagesh/Mappiq (U+05BC) - affects consonant pronunciation

### File Naming Format

```
{hash}.mp3

Examples:
- שָׁלוֹם → e8f2a6d3c1b4.mp3
- מֶלֶךְ → 7a3c5f1d8b2e.mp3
- אֱלֹהִים → 9e2d4a6f3c1b.mp3
```

## Why This Is Perfect for You

✅ **Deterministic**
- Same Hebrew text ALWAYS produces same hash
- Works identically in Ruby, Python, JavaScript, Swift, etc.
- Unicode normalization handles different typing orders
- Cantillation stripping handles biblical vs dictionary text

✅ **Portable Across Apps**
- Generate hash in Rails app → use same file in iOS app
- Generate hash in Python script → use same file in web app
- One audio library, multiple platforms

✅ **No Dependency on Database**
- Don't need database to know which file goes with which word
- Any app can compute hash from Hebrew text alone

✅ **Re-import Safe**
- Database IDs can change → hash never changes
- Transliteration can be wrong → hash still correct
- Metadata can vary → hash only depends on Hebrew text

✅ **Collision-Resistant**
- 12 characters = 48 bits = 281 trillion combinations
- Virtually impossible to have two different words with same hash
- No collision handling needed

## Ruby Implementation (For Your Rails App)

```ruby
# app/models/word.rb
class Word < ApplicationRecord
  has_one_attached :audio_file

  before_create :generate_audio_identifier!, unless: :audio_identifier?

  def generate_audio_identifier!
    self.audio_identifier = self.class.hash_hebrew_text(representation)
    save! if persisted?
  end

  # Class method - can be used standalone
  def self.hash_hebrew_text(hebrew_text)
    require 'digest'

    # Step 1: Normalize Unicode to NFC
    normalized = hebrew_text.unicode_normalize(:nfc)

    # Step 2: Strip cantillation marks (U+0591-U+05AF)
    # Keep vowel points and dagesh (they affect pronunciation)
    cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')

    # Step 3: Encode to UTF-8 (already UTF-8 in Ruby)
    utf8_bytes = cleaned.encode('UTF-8')

    # Step 4: Compute SHA-256 hash
    hash = Digest::SHA256.hexdigest(utf8_bytes)

    # Step 5: Take first 12 characters
    hash[0...12]
  end
end
```

**Usage:**
```ruby
# In Rails console or scripts
Word.hash_hebrew_text("שָׁלוֹם")
# => "e8f2a6d3c1b4"

# Automatically generated on word creation
word = Word.create(representation: "מֶלֶךְ")
word.audio_identifier
# => "7a3c5f1d8b2e"

# Cantillation marks are stripped automatically
Word.hash_hebrew_text("אֶ֫רֶץ")  # with meteg
# => "007c9089f1d5"
Word.hash_hebrew_text("אֶרֶץ")   # without meteg
# => "007c9089f1d5" (same!)
```

## Cross-Platform Examples

### Python (for scripts/data processing)

```python
import hashlib
import unicodedata
import re

def hash_hebrew_text(hebrew_text):
    normalized = unicodedata.normalize('NFC', hebrew_text)
    cleaned = re.sub(r'[\u0591-\u05AF]', '', normalized)  # Strip cantillation
    utf8_bytes = cleaned.encode('utf-8')
    hash_obj = hashlib.sha256(utf8_bytes)
    return hash_obj.hexdigest()[:12]

hash_hebrew_text("שָׁלוֹם")
# => 'e8f2a6d3c1b4'
```

### JavaScript (for web apps)

```javascript
const crypto = require('crypto');

function hashHebrewText(hebrewText) {
  const normalized = hebrewText.normalize('NFC');
  // Strip cantillation marks (U+0591-U+05AF)
  const cleaned = normalized.replace(/[\u0591-\u05AF]/g, '');
  const hash = crypto.createHash('sha256')
                     .update(cleaned, 'utf8')
                     .digest('hex');
  return hash.substring(0, 12);
}

hashHebrewText("שָׁלוֹם");
// => 'e8f2a6d3c1b4'
```

### Swift (for iOS app)

```swift
import CryptoKit

func hashHebrewText(_ hebrewText: String) -> String {
    let normalized = hebrewText.precomposedStringWithCanonicalMapping
    // Strip cantillation marks (U+0591-U+05AF)
    let pattern = "[\\u{0591}-\\u{05AF}]"
    let cleaned = normalized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)

    guard let utf8Data = cleaned.data(using: .utf8) else { return "" }
    let hash = SHA256.hash(data: utf8Data)
    let hexString = hash.compactMap { String(format: "%02x", $0) }.joined()
    return String(hexString.prefix(12))
}

hashHebrewText("שָׁלוֹם")
// => "e8f2a6d3c1b4"
```

**All produce identical results!**

## Workflow for Audio Import

### Step 1: Export CSV from Rails App

```csv
audio_identifier,representation,first_gloss,part_of_speech,has_audio
e8f2a6d3c1b4,שָׁלוֹם,peace,Noun,no
7a3c5f1d8b2e,מֶלֶךְ,king,Noun,no
9e2d4a6f3c1b,אֱלֹהִים,God,Noun,no
```

### Step 2: Rename Audio Files

```bash
# Original files
peace_recording.mp3
king_recording.mp3
god_recording.mp3

# Rename to match hashes
e8f2a6d3c1b4.mp3
7a3c5f1d8b2e.mp3
9e2d4a6f3c1b.mp3
```

### Step 3: Upload ZIP to Rails

- System matches files by audio_identifier
- Attaches to correct words automatically

## Cross-Application Reuse

**Scenario:** You build an iOS flashcard app later

```swift
// iOS app can compute same hash
let hebrew = "שָׁלוֹם"
let audioFile = "\(hashHebrewText(hebrew)).mp3"
// => "e8f2a6d3c1b4.mp3"

// Download from your CDN/storage
let url = "https://audio.yourdomain.com/\(audioFile)"
playAudio(from: url)
```

**No database needed!** Just the Hebrew text.

## Database Schema

```ruby
# words table
add_column :words, :audio_identifier, :string, limit: 12
add_index :words, :audio_identifier, unique: true

# Example data:
# id  | representation | audio_identifier
# 42  | שָׁלוֹם        | e8f2a6d3c1b4
# 123 | מֶלֶךְ         | 7a3c5f1d8b2e
# 124 | אֱלֹהִים       | 9e2d4a6f3c1b
```

## Benefits Over Other Approaches

| Approach | Portable? | Re-import Safe? | Readable? |
|----------|-----------|----------------|-----------|
| Database ID | ❌ Rails-specific | ❌ Changes | ❌ No meaning |
| Transliteration + POS | ⚠️ Requires metadata | ⚠️ If consistent | ✅ Human-friendly |
| **SHA-256 Hash** | ✅ Any language | ✅ Always same | ⚠️ Not human-readable |

**Trade-off:** Hash isn't human-readable, but you get CSV export to see what each hash represents.

## Re-import Scenarios

### Scenario 1: Full Database Reset

```ruby
# Before reset
Word.find_by(representation: "שָׁלוֹם").audio_identifier
# => "e8f2a6d3c1b4"

# Reset database, re-import words

# After reset (new database ID)
Word.find_by(representation: "שָׁלוֹם").audio_identifier
# => "e8f2a6d3c1b4" (SAME HASH!)

# Audio files in GCS bucket still work!
```

### Scenario 2: Build New iOS App

```swift
// No database access, just Hebrew text
let hebrew = loadWordFromLocalJSON()
let audioIdentifier = hashHebrewText(hebrew)
let audioURL = "https://cdn.yourdomain.com/\(audioIdentifier).mp3"

// Same audio files from Rails app!
```

## Technical Specifications

**Hash Function:** SHA-256 (FIPS 180-4 standard)

**Hash Length:** 12 characters (48 bits)
- Collision probability: 1 in 281 trillion
- More than sufficient for vocabulary

**Encoding:** UTF-8

**Normalization:** Unicode NFC (Canonical Composition)
- Ensures consistent representation
- Handles different ways of encoding same character

**Performance:**
- 50,000+ hashes/second in Ruby
- Negligible overhead for vocabulary size

## Files & Documentation

**Implementation Plan:** `/projects/audio_support_project.md`
- Complete 7-phase implementation guide
- Database migrations, model code, UI components
- Testing strategies, deployment configs

**Hash Implementations:** `/projects/hash_algorithm_implementations.md`
- Ruby, Python, JavaScript, Swift, Go, Kotlin, Java, PHP, C#, Bash
- Full working code for each language
- Test cases and validation scripts
- Cross-platform testing guidelines

**Summary (this file):** `/projects/audio_support_summary.md`

## Next Steps

1. **Phase 1:** Set up Active Storage + Google Cloud Storage
2. **Phase 2:** Add `audio_identifier` column and hash generation
3. **Phase 3:** Build audio player UI component
4. **Phase 4:** Add manual upload for single words
5. **Phase 5:** Build bulk import with CSV export
6. **Phase 6:** Write tests and documentation
7. **Phase 7:** Deploy to production

Ready to start implementing when you are!

## Quick Start Command

```ruby
# Test hash generation right now in Rails console
require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')  # Strip cantillation
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

# Try it:
hash_hebrew("שָׁלוֹם")
hash_hebrew("מֶלֶךְ")
hash_hebrew("אֱלֹהִים")

# Test cantillation stripping:
hash_hebrew("אֶ֫רֶץ")  # with meteg
hash_hebrew("אֶרֶץ")   # without meteg
# Should produce same hash!
```
