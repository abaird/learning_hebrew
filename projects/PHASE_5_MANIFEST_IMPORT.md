# Phase 5: Bulk Audio Import with Manifest

## Overview

Upload a single ZIP file containing:
1. `manifest.csv` - mapping between audio_identifier (hash) and MP3 filename
2. All MP3 files referenced in the manifest

This combines the best of both worlds:
- ✅ Single upload step
- ✅ Flexible filenames (keep your original names)
- ✅ Verifiable mappings before upload
- ✅ Easy to script locally

## ZIP Structure

```
audio_upload.zip
├── manifest.csv          # Required: hash-to-filename mapping
├── peace.mp3             # Original filenames preserved
├── king_noun.mp3
├── melekh_verb.mp3
├── shalom.mp3
└── ... more mp3 files
```

## Manifest Format

**File:** `manifest.csv`

**Format:**
```csv
audio_identifier,filename
e8f2a6d3c1b4,peace.mp3
7a3c5f1d8b2e,king_noun.mp3
9e2d4a6f3c1b,god.mp3
a1b2c3d4e5f6,shalom.mp3
```

**Rules:**
- Must have header row: `audio_identifier,filename`
- `audio_identifier`: 12-character hexadecimal hash
- `filename`: Name of MP3 file in the ZIP (can be any valid filename)
- Files can be in subdirectories within ZIP (manifest should include path)

## Complete Workflow

### Step 1: Generate Hashes

You can generate hashes locally using the same algorithm:

```ruby
# In Rails console, local script, or standalone Ruby file
require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')  # Strip cantillation
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

# Example usage
hash_hebrew("שָׁלוֹם")  # => "e8f2a6d3c1b4"
hash_hebrew("מֶלֶךְ")   # => "7a3c5f1d8b2e"
hash_hebrew("אֱלֹהִים")  # => "9e2d4a6f3c1b"
```

### Step 2: Create Manifest

**Option A: Manual Creation**
```csv
audio_identifier,filename
e8f2a6d3c1b4,peace.mp3
7a3c5f1d8b2e,king_noun.mp3
9e2d4a6f3c1b,god.mp3
```

**Option B: Script-Generated (Recommended)**

Create a Ruby script to generate the manifest:

```ruby
#!/usr/bin/env ruby
# generate_manifest.rb
# Usage: ruby generate_manifest.rb words.csv audio_dir/ > manifest.csv

require 'csv'
require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

words_csv = ARGV[0]    # CSV with Hebrew words
audio_dir = ARGV[1]    # Directory with MP3 files

puts "audio_identifier,filename"

CSV.foreach(words_csv, headers: true) do |row|
  hebrew = row['representation']
  gloss = row['gloss']

  hash = hash_hebrew(hebrew)

  # Match audio file by gloss (or any other logic you prefer)
  audio_file = Dir.glob("#{audio_dir}/*#{gloss}*.mp3").first

  if audio_file
    puts "#{hash},#{File.basename(audio_file)}"
  else
    STDERR.puts "WARNING: No audio for #{hebrew} (#{gloss})"
  end
end
```

**Usage:**
```bash
# Export words from Rails to CSV
# (Or use the "Download Audio Identifiers CSV" from import page)

# Generate manifest
ruby generate_manifest.rb exported_words.csv ~/audio_files/ > manifest.csv

# Review manifest (check for warnings)
cat manifest.csv
```

### Step 3: Create ZIP File

```bash
# Option 1: Command line
cd ~/audio_files
cp /path/to/manifest.csv .
zip -r audio_upload.zip manifest.csv *.mp3

# Option 2: macOS Finder
# - Put manifest.csv and all MP3s in a folder
# - Right-click folder → "Compress"

# Option 3: Windows
# - Put manifest.csv and all MP3s in a folder
# - Right-click folder → "Send to" → "Compressed folder"
```

**Verify ZIP contents:**
```bash
unzip -l audio_upload.zip

# Should show:
# manifest.csv
# peace.mp3
# king_noun.mp3
# etc.
```

### Step 4: Upload via Import Page

1. Navigate to `/import` in your Rails app
2. Scroll to "Bulk Audio Import" section
3. Select your `audio_upload.zip` file
4. Check "Overwrite existing" if you want to replace existing audio
5. Click "Import Audio Files"

### Step 5: Review Results

After upload completes, you'll see:

```
Audio import completed: 45 succeeded, 3 skipped, 2 failed

Errors:
- Word not found for audio_identifier: abc123def456 (shalom.mp3)
- Audio file not found in ZIP: missing.mp3
```

**Success:** Audio attached to words
**Skipped:** Words already have audio (if not overwriting)
**Failed:** Invalid identifiers, missing words, missing files

## Import Process (Backend)

The `AudioImportService` performs these steps:

1. **Extract and parse manifest.csv**
   - Validate CSV format
   - Check audio_identifier format (12-char hex)
   - Check filename format (.mp3)

2. **Validate referenced files exist in ZIP**
   - Ensure all files in manifest are present
   - Report missing files

3. **Process each manifest entry**
   - Look up word by audio_identifier
   - Check if audio already attached (skip if not overwriting)
   - Extract MP3 from ZIP
   - Attach to word using Active Storage

4. **Return results**
   - Count: success, skipped, failed
   - List of errors with details

## Error Handling

### Validation Errors

**Missing manifest.csv**
```
Error: No manifest.csv found in ZIP file
```
→ Fix: Ensure manifest.csv is in the root of the ZIP

**Malformed CSV**
```
Error: Malformed CSV: Unclosed quoted field on line 5
```
→ Fix: Check CSV syntax, ensure proper quoting

**Invalid audio_identifier**
```
Error: Invalid audio_identifier in manifest: xyz (must be 12-char hex)
```
→ Fix: Use `hash_hebrew()` to generate correct identifiers

### Import Errors

**File not in ZIP**
```
Error: Audio file not found in ZIP: missing.mp3
```
→ Fix: Ensure all files referenced in manifest are included in ZIP

**Word not found**
```
Error: Word not found for audio_identifier: e8f2a6d3c1b4 (peace.mp3)
```
→ Fix: Verify the word exists in database, or hash was generated correctly

**File processing error**
```
Error: Error processing peace.mp3: Invalid audio format
```
→ Fix: Check MP3 file is valid, not corrupted

## Tips & Best Practices

### Before Creating ZIP

1. **Test hash generation**
   ```ruby
   # Verify hashes match between local and server
   local_hash = hash_hebrew("שָׁלוֹם")
   server_hash = Word.hash_hebrew_text("שָׁלוֹם")
   puts "Match!" if local_hash == server_hash
   ```

2. **Export reference CSV from server**
   - Use "Download Audio Identifiers CSV" button
   - Compare your generated hashes with server hashes
   - Ensures algorithm consistency

3. **Validate manifest before zipping**
   ```ruby
   # Check all files exist
   CSV.foreach('manifest.csv', headers: true) do |row|
     filename = row['filename']
     unless File.exist?(filename)
       puts "WARNING: Missing file: #{filename}"
     end
   end
   ```

### During Import

1. **Start with small batch**
   - Test with 5-10 files first
   - Verify successful before uploading hundreds

2. **Review errors carefully**
   - Check for patterns (all files missing? wrong directory?)
   - Fix issues and re-upload

3. **Use overwrite sparingly**
   - Only check "Overwrite existing" if you need to replace audio
   - Otherwise, skipped files save processing time

### After Import

1. **Verify audio attached**
   ```ruby
   # In Rails console
   Word.where.not(id: Word.joins(:audio_file_attachment).select(:id)).count
   # => Number of words without audio
   ```

2. **Test playback**
   - Visit word show pages
   - Click play buttons
   - Ensure audio loads and plays correctly

## Manifest Generation Strategies

### Strategy 1: Match by Gloss

```ruby
# Assumes audio files named after English gloss
# peace.mp3, king.mp3, etc.

matching_file = audio_files.find { |f| f.downcase.include?(gloss.downcase) }
```

### Strategy 2: Match by Pattern

```ruby
# Assumes specific naming pattern
# word_001_peace.mp3, word_002_king.mp3

matching_file = audio_files.find { |f| f.match(/#{Regexp.escape(gloss)}/i) }
```

### Strategy 3: Explicit Mapping

```ruby
# Manual mapping for problematic cases
MANUAL_MAP = {
  "שָׁלוֹם" => "shalom_pronunciation.mp3",
  "מֶלֶךְ" => "melekh_male_voice.mp3"
}

matching_file = MANUAL_MAP[hebrew] || auto_match(hebrew, audio_files)
```

### Strategy 4: Interactive

```ruby
# Prompt for each word
puts "Audio file for #{hebrew} (#{gloss})?"
puts "Available files: #{audio_files.join(', ')}"
filename = gets.chomp
```

## Troubleshooting

### "No valid entries found in manifest.csv"

**Causes:**
- Empty manifest
- Missing header row
- All rows have invalid format

**Fix:**
```csv
audio_identifier,filename  ← Must have this header!
e8f2a6d3c1b4,peace.mp3
```

### "Manifest references missing file: peace.mp3"

**Causes:**
- File not in ZIP
- Typo in manifest filename
- File in subdirectory but manifest doesn't include path

**Fix:**
```bash
# Check ZIP contents
unzip -l audio_upload.zip

# If file is in subdirectory:
audio_identifier,filename
e8f2a6d3c1b4,audio_files/peace.mp3  ← Include path
```

### Hashes don't match server

**Cause:** Different normalization or cantillation handling

**Fix:**
```ruby
# Ensure EXACT same algorithm
def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)       # Must use NFC
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '') # Strip cantillation
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

# Test against server
server_hash = Word.hash_hebrew_text("שָׁלוֹם")
local_hash = hash_hebrew("שָׁלוֹם")
puts "Server: #{server_hash}"
puts "Local:  #{local_hash}"
```

## Example End-to-End Workflow

```bash
# 1. Export words from Rails
curl https://myapp.com/import/export_audio_identifiers.csv > words.csv

# 2. Prepare audio files in directory
ls ~/hebrew_audio/
# peace.mp3
# king.mp3
# god.mp3

# 3. Generate manifest
ruby generate_manifest.rb words.csv ~/hebrew_audio/ > manifest.csv

# Output (to STDERR):
# Matched: שָׁלוֹם (peace) -> peace.mp3
# Matched: מֶלֶךְ (king) -> king.mp3
# Matched: אֱלֹהִים (god) -> god.mp3

# 4. Review manifest
cat manifest.csv
# audio_identifier,filename
# e8f2a6d3c1b4,peace.mp3
# 7a3c5f1d8b2e,king.mp3
# 9e2d4a6f3c1b,god.mp3

# 5. Create ZIP
cd ~/hebrew_audio
cp /path/to/manifest.csv .
zip audio_upload.zip manifest.csv *.mp3

# 6. Upload via web interface
# Navigate to /import, select audio_upload.zip, click Import

# 7. Verify results in Rails console
Word.where(audio_identifier: 'e8f2a6d3c1b4').first.audio_attached?
# => true
```

## Summary

**Key Benefits:**
- ✅ One-step upload (single ZIP)
- ✅ Keep original filenames
- ✅ Verify mappings before upload
- ✅ Easy to script and automate
- ✅ Clear error reporting

**Requirements:**
- manifest.csv with hash-to-filename mappings
- All referenced MP3 files in ZIP
- Valid 12-character hex hashes

**Next Steps:**
- See full implementation in `/projects/audio_support_project.md`
- Generate hashes using provided `hash_hebrew()` function
- Create manifest and ZIP, then upload!
