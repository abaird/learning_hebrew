# Audio Support for Hebrew Words - Implementation Plan

## Project Overview

Add audio pronunciation support for Hebrew words with smart loading, efficient storage, and bulk import capabilities.

## Key Requirements Analysis

1. **Performance**: On-demand loading only when user clicks play
2. **UI Integration**: Audio buttons on word show and dictionary pages
3. **File Identification**: Numeric/non-Hebrew naming system
4. **Bulk Import**: Reuse existing import page infrastructure
5. **Format**: Industry-standard audio format
6. **Storage**: Scalable solution that doesn't bloat git repository

## Recommended Architecture

### Storage Strategy: Active Storage + Google Cloud Storage

**Rationale:**
- ✅ Already using GCP/GKE infrastructure
- ✅ Doesn't bloat git repository (audio files stay out of version control)
- ✅ Scalable for thousands of audio files
- ✅ Rails Active Storage handles complexity (attachments, variants, direct uploads)
- ✅ Separate buckets for development/production environments
- ✅ CDN-ready for global performance
- ✅ Built-in authentication and authorization support
- ✅ No bandwidth concerns - files served directly from GCS (not through Rails)

**Alternative Considered:** Filesystem in `public/audio/`
- ❌ Would bloat git repo with binary files
- ❌ Not scalable for large collections
- ❌ Deployment complexity (syncing files across pods)
- ✅ Only viable for small, static collections (<50 files)

### Audio Format: MP3

**Rationale:**
- ✅ Universal browser support (100% compatibility)
- ✅ Good compression for speech (64-128kbps sufficient for clear Hebrew pronunciation)
- ✅ Patent-free since 2017
- ✅ Smallest file size for good quality speech
- ✅ Industry standard for web audio

**Encoding Recommendations:**
- Bitrate: 64-96kbps (speech-optimized)
- Sample rate: 44.1kHz or 48kHz
- Mono (single speaker pronunciation doesn't need stereo)
- Expected file size: ~60KB for 10-second pronunciation @ 64kbps

**Alternative Considered:** OGG/Opus
- ✅ Better quality at same bitrate
- ❌ Slightly worse browser support (no iOS Safari support for Opus)
- Decision: Stick with MP3 for maximum compatibility

### File Naming Strategy: Cryptographic Hash of Hebrew Representation

**Problem with Database IDs:**
- Database IDs change during re-imports or migrations
- Would break audio file associations
- Not suitable as permanent identifier

**Recommended Solution:** SHA-256 hash of normalized Hebrew representation

**Why Hash-Based Identifiers?**
- ✅ **Deterministic**: Same Hebrew text always produces same hash
- ✅ **Language-agnostic**: SHA-256 works identically in any programming language
- ✅ **Portable**: Can reuse audio files across different applications
- ✅ **Collision-resistant**: SHA-256 virtually eliminates collisions
- ✅ **Import-safe**: Survives database re-imports and migrations
- ✅ **No dependency on transliteration**: Works even if transliteration is missing/wrong

**Hash Algorithm (Language-Agnostic):**
```
1. Take Hebrew representation (raw string: "שָׁלוֹם")
2. Normalize Unicode to NFC form (canonical composition)
3. Strip cantillation marks (U+0591 - U+05AF) - keep vowel points!
4. Encode to UTF-8 bytes
5. Compute SHA-256 hash
6. Take first 12 characters of hexadecimal output
7. Result: "d4f8a9c2b1e3" (example)
```

**Why strip cantillation marks?**
- Cantillation marks (ta'amim) are musical notation for Torah chanting
- Same word may appear with/without cantillation in different sources
- They don't affect pronunciation - only the musical melody
- Stripping ensures: אֶ֫רֶץ (with meteg) hashes same as אֶרֶץ (without)

**What gets stripped vs kept:**
- ✗ STRIP: Cantillation marks (U+0591-U+05AF) - etnahta, tipcha, meteg, etc.
- ✓ KEEP: Vowel points (U+05B0-U+05BD, etc.) - patach, qamats, shva, etc.
- ✓ KEEP: Dagesh/Mappiq (U+05BC) - affects consonant pronunciation

**Identifier Format:** `{hash}.mp3`
```
Examples:
- שָׁלוֹם → "d4f8a9c2b1e3.mp3"
- מֶלֶךְ → "7a3c5f1d8b2e.mp3"
- אֱלֹהִים → "9e2d4a6f3c1b.mp3"
```

**Key Properties:**
- ✅ **Immutable**: Hebrew text never changes, so hash never changes
- ✅ **Portable**: Same hash algorithm works in Ruby, Python, JavaScript, Swift, etc.
- ✅ **Unique**: 12-char hex = 48 bits = 281 trillion combinations (no collisions for vocabulary)
- ✅ **Reusable**: Can use same audio files in mobile app, web app, desktop app
- ✅ **Fast lookup**: Indexed column for O(1) database queries

**Implementation Details:**
- Stored in dedicated `audio_identifier` column (string, indexed, unique)
- Auto-generated on word creation via `before_create` callback
- Uses Unicode NFC normalization to handle different representations
- 12-character hex string (sufficient for uniqueness, keeps filenames short)
- No collision handling needed (SHA-256 collision probability is negligible)

**Re-import Behavior:**
- When re-importing words, hash regenerates identically (deterministic)
- Audio files automatically re-associate with re-imported words
- Audio files in GCS bucket remain untouched during word re-import
- Works even if word ID, transliteration, or other metadata changes
- Only Hebrew representation matters

**Active Storage Naming:**
- Active Storage generates its own internal filenames (UUIDs)
- Original filename stored as `{hash}.mp3`
- Lookup during import: find word by audio_identifier (hash), attach file

## Implementation Phases

### Phase 1: Active Storage Setup & Infrastructure

**Goals:**
- Configure Active Storage with Google Cloud Storage
- Create GCS buckets for development and production
- Set up service account permissions

**Tasks:**

1. **Install Active Storage**
   ```bash
   bin/rails active_storage:install
   bin/rails db:migrate
   ```

2. **Configure GCS Storage**
   - Create GCS buckets:
     - `learning-hebrew-audio-dev` (development)
     - `learning-hebrew-audio-prod` (production)
   - Set bucket permissions (private with signed URLs)
   - Add CORS configuration for direct uploads (future enhancement)

3. **Update `config/storage.yml`**
   ```yaml
   google_dev:
     service: GCS
     project: learning-hebrew-1758491674
     bucket: learning-hebrew-audio-dev
     credentials: <%= Rails.root.join("config/gcs_key.json") %>

   google_prod:
     service: GCS
     project: learning-hebrew-1758491674
     bucket: learning-hebrew-audio-prod
     credentials: <%= Rails.root.join("config/gcs_key.json") %>
   ```

4. **Update environment configs**
   - Development: `config.active_storage.service = :local` (or `:google_dev`)
   - Production: `config.active_storage.service = :google_prod`
   - Test: `config.active_storage.service = :test`

5. **Add GCS gem**
   ```ruby
   # Gemfile
   gem "google-cloud-storage", "~> 1.47", require: false
   ```

6. **Create service account for storage access**
   - Use existing GKE service account or create new one
   - Grant "Storage Object Admin" role to bucket
   - Download credentials JSON (add to secret manager)

**Files Changed:**
- `db/migrate/XXXXXX_create_active_storage_tables.rb` (generated)
- `config/storage.yml`
- `config/environments/development.rb`
- `config/environments/production.rb`
- `Gemfile`
- `k8s/secrets-prod.yaml` (GCS credentials)

**Testing:**
```ruby
# In rails console
blob = ActiveStorage::Blob.create_and_upload!(
  io: File.open("test.mp3"),
  filename: "test.mp3"
)
blob.url # Should return signed GCS URL
```

---

### Phase 2: Word Model, Audio Identifier & Audio Attachment

**Goals:**
- Add `audio_identifier` column to words table
- Generate permanent identifiers for all existing words
- Add audio attachment to Word model
- Create helper methods for audio presence/URL
- Update word factory for testing

**Tasks:**

1. **Create migration for audio_identifier column**
   ```ruby
   # db/migrate/XXXXXX_add_audio_identifier_to_words.rb
   class AddAudioIdentifierToWords < ActiveRecord::Migration[8.0]
     def change
       add_column :words, :audio_identifier, :string
       add_index :words, :audio_identifier, unique: true

       # Backfill existing words
       reversible do |dir|
         dir.up do
           Word.find_each do |word|
             word.generate_audio_identifier!
           end
         end
       end
     end
   end
   ```

2. **Add audio identifier generation to Word model**
   ```ruby
   # app/models/word.rb
   class Word < ApplicationRecord
     has_one_attached :audio_file

     # Generate audio_identifier before creation
     before_create :generate_audio_identifier!, unless: :audio_identifier?

     # Helper methods
     def audio_attached?
       audio_file.attached?
     end

     def audio_url
       return nil unless audio_attached?
       Rails.application.routes.url_helpers.rails_blob_path(audio_file, only_path: true)
     end

     def generate_audio_identifier!
       self.audio_identifier = self.class.hash_hebrew_text(representation)
       save! if persisted?
     end

     # Class method for generating hash from Hebrew text
     # This can be used standalone for naming audio files externally
     def self.hash_hebrew_text(hebrew_text)
       require 'digest'

       # Step 1: Normalize Unicode to NFC (canonical composition)
       normalized = hebrew_text.unicode_normalize(:nfc)

       # Step 2: Strip cantillation marks (U+0591-U+05AF)
       # Keep vowel points and dagesh (they affect pronunciation)
       cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')

       # Step 3: Encode to UTF-8 bytes (Ruby strings are already UTF-8)
       utf8_bytes = cleaned.encode('UTF-8')

       # Step 4: Compute SHA-256 hash
       hash = Digest::SHA256.hexdigest(utf8_bytes)

       # Step 5: Take first 12 characters (48 bits)
       hash[0...12]
     end

     # Validation
     validates :audio_identifier, uniqueness: true, allow_nil: true
     validates :audio_file, content_type: ['audio/mpeg', 'audio/mp3'],
                            size: { less_than: 5.megabytes }
   end
   ```

3. **Update Word fixtures/factories**
   ```ruby
   # spec/factories/words.rb
   FactoryBot.define do
     factory :word do
       # ... existing attributes ...

       trait :with_audio do
         after(:create) do |word|
           word.audio_file.attach(
             io: File.open(Rails.root.join('spec/fixtures/files/sample_audio.mp3')),
             filename: "#{word.audio_identifier}.mp3",
             content_type: 'audio/mpeg'
           )
         end
       end
     end
   end
   ```

4. **Add sample audio file for testing**
   - Create `spec/fixtures/files/sample_audio.mp3` (small test file)

**Files Changed:**
- `db/migrate/XXXXXX_add_audio_identifier_to_words.rb` (new)
- `app/models/word.rb`
- `spec/factories/words.rb`
- `spec/fixtures/files/sample_audio.mp3` (new)

**Testing:**
```ruby
# RSpec examples
describe ".hash_hebrew_text" do
  it "generates consistent hash for same Hebrew text" do
    hash1 = Word.hash_hebrew_text("שָׁלוֹם")
    hash2 = Word.hash_hebrew_text("שָׁלוֹם")
    expect(hash1).to eq(hash2)
  end

  it "generates 12-character hexadecimal string" do
    hash = Word.hash_hebrew_text("מֶלֶךְ")
    expect(hash).to match(/^[a-f0-9]{12}$/)
  end

  it "generates different hashes for different words" do
    hash1 = Word.hash_hebrew_text("שָׁלוֹם")
    hash2 = Word.hash_hebrew_text("מֶלֶךְ")
    expect(hash1).not_to eq(hash2)
  end

  it "handles Unicode normalization" do
    # Same word with different Unicode representations should produce same hash
    # (if they normalize to the same form)
    text1 = "שָׁלוֹם"
    text2 = "שָׁלוֹם".unicode_normalize(:nfc)
    hash1 = Word.hash_hebrew_text(text1)
    hash2 = Word.hash_hebrew_text(text2)
    expect(hash1).to eq(hash2)
  end
end

describe "audio_identifier generation" do
  it "generates identifier on word creation" do
    word = create(:word, representation: "שָׁלוֹם")
    expect(word.audio_identifier).to be_present
    expect(word.audio_identifier).to match(/^[a-f0-9]{12}$/)
  end

  it "generates same identifier for same Hebrew text" do
    word1 = create(:word, representation: "שָׁלוֹם")
    word2 = build(:word, representation: "שָׁלוֹם")
    word2.generate_audio_identifier!

    expect(word1.audio_identifier).to eq(word2.audio_identifier)
  end

  it "does not regenerate if already set" do
    word = create(:word, representation: "שָׁלוֹם")
    original_id = word.audio_identifier

    word.representation = "מֶלֶךְ"
    word.save!

    expect(word.audio_identifier).to eq(original_id) # Unchanged
  end
end

describe "audio attachment" do
  it "attaches audio file" do
    word = create(:word, :with_audio)
    expect(word.audio_attached?).to be true
  end

  it "returns audio URL when attached" do
    word = create(:word, :with_audio)
    expect(word.audio_url).to be_present
  end
end
```

**Migration Testing:**
```ruby
# Test backfill in rails console
Word.where(audio_identifier: nil).count # Should be 0 after migration
Word.pluck(:audio_identifier).uniq.count == Word.count # All unique

# Test hash generation manually
Word.hash_hebrew_text("שָׁלוֹם") # Should return consistent 12-char hex
```

---

### Phase 3: Audio Player UI Component

**Goals:**
- Create reusable audio player partial
- Add audio buttons to word show page
- Style audio controls with Tailwind CSS
- Implement lazy loading (only fetch when user clicks play)

**Tasks:**

1. **Create audio player partial**
   ```erb
   <!-- app/views/shared/_audio_player.html.erb -->
   <div class="audio-player inline-flex items-center" data-controller="audio-player">
     <% if word.audio_attached? %>
       <button
         data-audio-player-target="playButton"
         data-action="click->audio-player#play"
         data-audio-url="<%= word.audio_url %>"
         class="inline-flex items-center px-3 py-1 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
         title="Play pronunciation"
       >
         <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
           <!-- Play icon -->
         </svg>
         Play
       </button>
       <audio data-audio-player-target="audio" preload="none"></audio>
       <span data-audio-player-target="status" class="ml-2 text-sm text-gray-500"></span>
     <% else %>
       <span class="text-sm text-gray-400">No audio available</span>
     <% end %>
   </div>
   ```

2. **Create Stimulus audio player controller**
   ```javascript
   // app/javascript/controllers/audio_player_controller.js
   import { Controller } from "@hotwired/stimulus"

   export default class extends Controller {
     static targets = ["audio", "playButton", "status"]

     play(event) {
       event.preventDefault()
       const audioUrl = event.currentTarget.dataset.audioUrl

       // Lazy load: only set src when user clicks play
       if (!this.audioTarget.src) {
         this.audioTarget.src = audioUrl
         this.statusTarget.textContent = "Loading..."
       }

       this.audioTarget.play()
       this.playButtonTarget.disabled = true
       this.statusTarget.textContent = "Playing..."
     }

     connect() {
       this.audioTarget.addEventListener('ended', () => {
         this.playButtonTarget.disabled = false
         this.statusTarget.textContent = ""
       })

       this.audioTarget.addEventListener('error', () => {
         this.statusTarget.textContent = "Error loading audio"
         this.playButtonTarget.disabled = false
       })
     }
   }
   ```

3. **Add audio player to word show page**
   ```erb
   <!-- app/views/words/show.html.erb -->
   <div class="mb-4">
     <h2 class="text-4xl font-hebrew"><%= @word.representation %></h2>
     <%= render 'shared/audio_player', word: @word %>
   </div>
   ```

4. **Add audio indicator to dictionary view**
   - Option A: Small speaker icon next to words with audio
   - Option B: Audio button in the word detail popup
   - Recommendation: Add to popup (less visual clutter)

**Files Changed:**
- `app/views/shared/_audio_player.html.erb` (new)
- `app/javascript/controllers/audio_player_controller.js` (new)
- `app/views/words/show.html.erb`
- `app/views/dictionary/index.html.erb` (add audio to popup)

**Performance Notes:**
- `preload="none"` prevents audio loading until user clicks play
- Lazy src assignment only happens on first play
- No bandwidth wasted on unused audio files
- Audio files served directly from GCS (not through Rails)

---

### Phase 4: Manual Single Audio Upload (Admin UI)

**Goals:**
- Add audio upload field to word edit form
- Allow superusers to upload/replace audio files
- Display current audio status in form

**Tasks:**

1. **Update word form to include audio upload**
   ```erb
   <!-- app/views/words/_form.html.erb -->
   <div class="mb-4">
     <%= form.label :audio_file, "Audio Pronunciation", class: "block text-sm font-medium text-gray-700" %>

     <% if word.audio_attached? %>
       <div class="mb-2 text-sm text-green-600">
         ✓ Audio file attached: <%= word.audio_file.filename %>
         <%= link_to "Remove", remove_audio_word_path(word), method: :delete,
                     data: { confirm: "Remove audio file?" },
                     class: "ml-2 text-red-600 hover:text-red-800" %>
       </div>
       <%= render 'shared/audio_player', word: word %>
     <% else %>
       <p class="mb-2 text-sm text-gray-500">No audio file attached</p>
     <% end %>

     <%= form.file_field :audio_file,
                         accept: "audio/mpeg,audio/mp3",
                         class: "mt-1 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" %>
     <p class="mt-1 text-xs text-gray-500">MP3 format, max 5MB</p>
   </div>
   ```

2. **Update WordsController to handle audio upload**
   ```ruby
   # app/controllers/words_controller.rb
   def update
     authorize @word
     if @word.update(word_params)
       redirect_to @word, notice: 'Word updated successfully.'
     else
       render :edit
     end
   end

   def remove_audio
     authorize @word
     @word.audio_file.purge
     redirect_to edit_word_path(@word), notice: 'Audio removed successfully.'
   end

   private

   def word_params
     params.require(:word).permit(
       # ... existing params ...
       :audio_file
     )
   end
   ```

3. **Add route for audio removal**
   ```ruby
   # config/routes.rb
   resources :words do
     member do
       delete :remove_audio
     end
   end
   ```

**Files Changed:**
- `app/views/words/_form.html.erb`
- `app/controllers/words_controller.rb`
- `config/routes.rb`

**Authorization:**
- Only superusers can upload/remove audio files
- Enforced via WordPolicy (existing authorization framework)

---

### Phase 5: Bulk Audio Import System

**Goals:**
- Bulk upload multiple audio files via import page
- Map files to words using CSV manifest
- Provide upload progress and error reporting
- Support ZIP file upload with extraction and validation

**Tasks:**

1. **Design import strategy: ZIP with CSV Manifest** (RECOMMENDED)

   **ZIP Structure:**
   ```
   audio_upload.zip
   ├── manifest.csv          # Mapping: audio_identifier,filename
   ├── peace.mp3             # Original filenames preserved
   ├── king_noun.mp3
   ├── melekh_verb.mp3
   └── ... more mp3 files
   ```

   **Manifest CSV Format:**
   ```csv
   audio_identifier,filename
   e8f2a6d3c1b4,peace.mp3
   7a3c5f1d8b2e,king_noun.mp3
   9e2d4a6f3c1b,god.mp3
   ```

   **Why this approach?**
   - ✅ **Single upload step** - one ZIP contains everything
   - ✅ **Flexible filenames** - keep your original audio file names
   - ✅ **Verifiable** - can review manifest before uploading
   - ✅ **Error checking** - validate manifest references existing files
   - ✅ **Traceable** - clear mapping between hash and source file
   - ✅ **Scriptable** - easy to generate manifest with local script

   **Workflow:**
   1. Generate hashes locally using `Word.hash_hebrew_text()`
   2. Create CSV manifest mapping hashes to your audio filenames
   3. Create ZIP containing manifest.csv + all MP3 files
   4. Upload single ZIP file
   5. System validates manifest and imports audio

2. **Add ZIP import form to import page**
   ```erb
   <!-- app/views/import/new.html.erb -->
   <div class="mb-8">
     <h2 class="text-2xl font-bold mb-4">Bulk Audio Import</h2>

     <!-- Export audio identifiers for reference -->
     <div class="mb-4 p-4 bg-blue-50 border border-blue-200 rounded">
       <h3 class="font-semibold mb-2">Reference: Export Audio Identifiers</h3>
       <p class="text-sm text-gray-700 mb-2">
         Download a CSV with audio identifiers (hashes) for all words to help you create your manifest.
       </p>
       <%= link_to "Download Audio Identifiers CSV",
                   export_audio_identifiers_path(format: :csv),
                   class: "inline-block px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700" %>
     </div>

     <!-- Import instructions -->
     <div class="mb-4 p-4 bg-gray-50 border border-gray-200 rounded">
       <h3 class="font-semibold mb-2">Import Instructions</h3>
       <p class="text-sm text-gray-700 mb-2">
         Upload a ZIP file containing:
       </p>
       <ul class="text-sm text-gray-700 list-disc ml-5 space-y-1">
         <li><code class="bg-white px-1">manifest.csv</code> - mapping file (audio_identifier,filename)</li>
         <li>MP3 files referenced in the manifest</li>
       </ul>
       <p class="text-xs text-gray-600 mt-2">
         Example manifest.csv:
       </p>
       <pre class="text-xs bg-white p-2 rounded mt-1 overflow-x-auto">audio_identifier,filename
e8f2a6d3c1b4,peace.mp3
7a3c5f1d8b2e,king_noun.mp3</pre>
     </div>

     <!-- Import form -->
     <div class="p-4 bg-gray-50 border border-gray-200 rounded">
       <h3 class="font-semibold mb-2">Upload Audio ZIP</h3>
       <%= form_with url: import_audio_path, multipart: true, local: true do |f| %>
         <div class="mb-4">
           <%= f.label :audio_zip, "Audio ZIP File", class: "block text-sm font-medium text-gray-700" %>
           <%= f.file_field :audio_zip, accept: ".zip", required: true,
                            class: "mt-1 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" %>
           <p class="mt-1 text-xs text-gray-500">
             ZIP file containing manifest.csv and MP3 files
           </p>
         </div>

         <div class="mb-4">
           <label class="flex items-center">
             <%= f.check_box :overwrite_existing, class: "mr-2" %>
             <span class="text-sm text-gray-700">Overwrite existing audio files</span>
           </label>
         </div>

         <%= f.submit "Import Audio Files", class: "px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700" %>
       <% end %>
     </div>
   </div>
   ```

3. **Create AudioImportService**
   ```ruby
   # app/services/audio_import_service.rb
   require 'csv'

   class AudioImportService
     def initialize(zip_file_path, overwrite: false)
       @zip_file_path = zip_file_path
       @overwrite = overwrite
       @results = { success: 0, skipped: 0, failed: 0, errors: [] }
       @manifest = {}
     end

     def import
       require 'zip'

       Zip::File.open(@zip_file_path) do |zip_file|
         # Step 1: Parse manifest.csv
         manifest_entry = zip_file.find { |e| e.name.end_with?('manifest.csv') }

         unless manifest_entry
           @results[:errors] << "No manifest.csv found in ZIP file"
           return @results
         end

         parse_manifest(manifest_entry)

         # Step 2: Validate manifest entries reference files that exist
         validate_manifest_files(zip_file)

         # Step 3: Process each audio file according to manifest
         @manifest.each do |audio_identifier, filename|
           audio_entry = find_audio_file(zip_file, filename)

           if audio_entry
             process_audio_file(audio_identifier, audio_entry, filename)
           else
             @results[:failed] += 1
             @results[:errors] << "Audio file not found in ZIP: #{filename}"
           end
         end
       end

       @results
     end

     private

     def parse_manifest(manifest_entry)
       csv_content = manifest_entry.get_input_stream.read

       CSV.parse(csv_content, headers: true) do |row|
         audio_identifier = row['audio_identifier']&.strip
         filename = row['filename']&.strip

         # Validate audio_identifier format
         unless audio_identifier&.match?(/^[a-f0-9]{12}$/)
           @results[:errors] << "Invalid audio_identifier in manifest: #{audio_identifier}"
           next
         end

         # Validate filename
         unless filename&.end_with?('.mp3')
           @results[:errors] << "Invalid filename in manifest: #{filename} (must be .mp3)"
           next
         end

         @manifest[audio_identifier] = filename
       end

       if @manifest.empty?
         @results[:errors] << "No valid entries found in manifest.csv"
       end
     rescue CSV::MalformedCSVError => e
       @results[:errors] << "Malformed CSV: #{e.message}"
     rescue => e
       @results[:errors] << "Error parsing manifest: #{e.message}"
     end

     def validate_manifest_files(zip_file)
       @manifest.each do |audio_identifier, filename|
         entry = find_audio_file(zip_file, filename)
         unless entry
           @results[:errors] << "Manifest references missing file: #{filename}"
         end
       end
     end

     def find_audio_file(zip_file, filename)
       # Support files in root or subdirectories
       zip_file.find { |e| e.name.end_with?(filename) && !e.directory? }
     end

     def process_audio_file(audio_identifier, entry, original_filename)
       # Find word by audio_identifier
       word = Word.find_by(audio_identifier: audio_identifier)

       unless word
         @results[:failed] += 1
         @results[:errors] << "Word not found for audio_identifier: #{audio_identifier} (#{original_filename})"
         return
       end

       # Check if audio already exists
       if word.audio_attached? && !@overwrite
         @results[:skipped] += 1
         return
       end

       # Attach audio file
       word.audio_file.attach(
         io: StringIO.new(entry.get_input_stream.read),
         filename: "#{audio_identifier}.mp3",  # Store with hash as filename
         content_type: 'audio/mpeg'
       )

       @results[:success] += 1
     rescue => e
       @results[:failed] += 1
       @results[:errors] << "Error processing #{original_filename}: #{e.message}"
     end
   end
   ```

4. **Add export and import actions to ImportController**
   ```ruby
   # app/controllers/import_controller.rb
   def export_audio_identifiers
     authorize :import, :create?

     respond_to do |format|
       format.csv do
         csv_data = CSV.generate do |csv|
           csv << ['audio_identifier', 'representation', 'first_gloss', 'part_of_speech', 'has_audio']

           Word.includes(:glosses, :part_of_speech_category)
               .order(:audio_identifier)
               .find_each do |word|
             csv << [
               word.audio_identifier,
               word.representation,
               word.glosses.first&.text || '',
               word.part_of_speech_category&.name || '',
               word.audio_attached? ? 'yes' : 'no'
             ]
           end
         end

         send_data csv_data,
                   filename: "audio_identifiers_#{Date.today}.csv",
                   type: 'text/csv',
                   disposition: 'attachment'
       end
     end
   end

   def import_audio
     authorize :import, :create?

     unless params[:audio_zip]
       redirect_to import_path, alert: 'Please select a ZIP file'
       return
     end

     zip_file = params[:audio_zip]
     overwrite = params[:overwrite_existing] == '1'

     # Save uploaded file temporarily
     temp_path = Rails.root.join('tmp', 'audio_import.zip')
     File.open(temp_path, 'wb') do |file|
       file.write(zip_file.read)
     end

     # Import audio files
     service = AudioImportService.new(temp_path, overwrite: overwrite)
     results = service.import

     # Clean up
     File.delete(temp_path) if File.exist?(temp_path)

     # Display results
     flash[:notice] = "Audio import completed: #{results[:success]} succeeded, #{results[:skipped]} skipped, #{results[:failed]} failed"
     flash[:alert] = results[:errors].join(', ') if results[:errors].any?

     redirect_to import_path
   end
   ```

5. **Add routes**
   ```ruby
   # config/routes.rb
   get 'import/export_audio_identifiers', to: 'import#export_audio_identifiers', as: :export_audio_identifiers
   post 'import/audio', to: 'import#import_audio', as: :import_audio
   ```

6. **Add rubyzip gem**
   ```ruby
   # Gemfile
   gem 'rubyzip', '~> 2.3'
   ```

**Files Changed:**
- `app/views/import/new.html.erb`
- `app/services/audio_import_service.rb` (new)
- `app/controllers/import_controller.rb`
- `config/routes.rb`
- `Gemfile`

**Usage Instructions:**

**Step 1: Generate hashes locally**
```ruby
# In Rails console or local script
require 'digest'

def hash_hebrew(text)
  normalized = text.unicode_normalize(:nfc)
  cleaned = normalized.gsub(/[\u0591-\u05AF]/, '')
  Digest::SHA256.hexdigest(cleaned.encode('UTF-8'))[0...12]
end

# Generate hash for your words
hash_hebrew("שָׁלוֹם")  # => "e8f2a6d3c1b4"
```

**Step 2: Create manifest.csv**
```csv
audio_identifier,filename
e8f2a6d3c1b4,peace.mp3
7a3c5f1d8b2e,king_noun.mp3
9e2d4a6f3c1b,god.mp3
```

**Step 3: Create ZIP file**
```
audio_upload.zip
├── manifest.csv
├── peace.mp3
├── king_noun.mp3
└── god.mp3
```

**Step 4: Upload ZIP via import page**

**Step 5: Review results**
- Success: Files attached to words
- Skipped: Words already have audio (if not overwriting)
- Failed: Invalid identifiers, missing files, etc.

**Reference CSV Export (Optional):**
The "Download Audio Identifiers CSV" button provides a reference:
```csv
audio_identifier,representation,first_gloss,part_of_speech,has_audio
e8f2a6d3c1b4,שָׁלוֹם,peace,Noun,no
7a3c5f1d8b2e,מֶלֶךְ,king,Noun,yes
```

**Error Handling:**
- Missing manifest.csv: Import aborted with error
- Invalid audio_identifier format: Entry skipped, logged
- Manifest references missing file: Entry skipped, logged
- Word not found for identifier: Entry skipped, logged
- File processing errors: Entry skipped, logged with details
- Partial imports succeed (don't fail entire batch on one error)

---

### Phase 6: Testing & Documentation

**Goals:**
- Comprehensive test coverage for audio features
- Update CLAUDE.md with audio documentation
- Create user documentation for audio import

**Tasks:**

1. **Model specs**
   ```ruby
   # spec/models/word_spec.rb
   describe 'audio attachment' do
     it 'attaches audio file' do
       word = create(:word, :with_audio)
       expect(word.audio_attached?).to be true
     end

     it 'returns audio URL' do
       word = create(:word, :with_audio)
       expect(word.audio_url).to be_present
     end

     it 'validates content type' do
       word = build(:word)
       word.audio_file.attach(
         io: StringIO.new('fake content'),
         filename: 'test.txt',
         content_type: 'text/plain'
       )
       expect(word).not_to be_valid
     end
   end
   ```

2. **Controller specs**
   ```ruby
   # spec/requests/words_spec.rb
   describe 'audio upload' do
     it 'allows superuser to upload audio' do
       sign_in superuser
       word = create(:word)
       audio = fixture_file_upload('sample_audio.mp3', 'audio/mpeg')

       patch word_path(word), params: { word: { audio_file: audio } }

       expect(word.reload.audio_attached?).to be true
     end

     it 'prevents regular user from uploading audio' do
       sign_in user
       word = create(:word)
       audio = fixture_file_upload('sample_audio.mp3', 'audio/mpeg')

       expect {
         patch word_path(word), params: { word: { audio_file: audio } }
       }.to raise_error(Pundit::NotAuthorizedError)
     end
   end
   ```

3. **Import service specs**
   ```ruby
   # spec/services/audio_import_service_spec.rb
   describe AudioImportService do
     let(:zip_path) { Rails.root.join('spec/fixtures/files/audio_import.zip') }

     it 'imports audio files by word ID' do
       word1 = create(:word, id: 42)
       word2 = create(:word, id: 123)

       service = AudioImportService.new(zip_path)
       results = service.import

       expect(results[:success]).to eq(2)
       expect(word1.reload.audio_attached?).to be true
       expect(word2.reload.audio_attached?).to be true
     end

     it 'skips existing audio when overwrite is false' do
       word = create(:word, :with_audio, id: 42)

       service = AudioImportService.new(zip_path, overwrite: false)
       results = service.import

       expect(results[:skipped]).to eq(1)
     end

     it 'overwrites existing audio when overwrite is true' do
       word = create(:word, :with_audio, id: 42)

       service = AudioImportService.new(zip_path, overwrite: true)
       results = service.import

       expect(results[:success]).to eq(1)
     end
   end
   ```

4. **System specs (feature tests)**
   ```ruby
   # spec/system/audio_playback_spec.rb
   describe 'Audio playback', type: :system, js: true do
     it 'plays audio when button is clicked' do
       word = create(:word, :with_audio)
       sign_in user

       visit word_path(word)
       click_button 'Play'

       expect(page).to have_text('Playing...')
     end

     it 'shows no audio message when audio not attached' do
       word = create(:word)
       sign_in user

       visit word_path(word)
       expect(page).to have_text('No audio available')
     end
   end
   ```

5. **Update CLAUDE.md documentation**
   - Add audio architecture section
   - Document import process
   - Add troubleshooting guide

6. **Create user guide**
   - Create `docs/audio_import_guide.md`
   - Step-by-step instructions for preparing and importing audio
   - Naming conventions and file format requirements

**Files Changed:**
- `spec/models/word_spec.rb`
- `spec/requests/words_spec.rb`
- `spec/services/audio_import_service_spec.rb` (new)
- `spec/system/audio_playback_spec.rb` (new)
- `spec/fixtures/files/audio_import.zip` (new test fixture)
- `CLAUDE.md`
- `docs/audio_import_guide.md` (new)

---

### Phase 7: Deployment & Production Configuration

**Goals:**
- Configure GCS buckets and permissions
- Update Kubernetes manifests with GCS credentials
- Test in production environment
- Monitor storage costs

**Tasks:**

1. **Create GCS buckets**
   ```bash
   # Development bucket
   gcloud storage buckets create gs://learning-hebrew-audio-dev \
     --project=learning-hebrew-1758491674 \
     --location=us-central1 \
     --uniform-bucket-level-access

   # Production bucket
   gcloud storage buckets create gs://learning-hebrew-audio-prod \
     --project=learning-hebrew-1758491674 \
     --location=us-central1 \
     --uniform-bucket-level-access
   ```

2. **Configure bucket CORS (for future direct uploads)**
   ```bash
   # Create cors.json
   cat > cors.json <<EOF
   [
     {
       "origin": ["https://learning-hebrew.bairdsnet.net"],
       "method": ["GET", "HEAD", "PUT", "POST"],
       "responseHeader": ["Content-Type"],
       "maxAgeSeconds": 3600
     }
   ]
   EOF

   # Apply CORS
   gcloud storage buckets update gs://learning-hebrew-audio-prod --cors-file=cors.json
   ```

3. **Create service account for storage access**
   ```bash
   # Create service account
   gcloud iam service-accounts create audio-storage-sa \
     --display-name="Audio Storage Service Account"

   # Grant storage permissions
   gcloud storage buckets add-iam-policy-binding gs://learning-hebrew-audio-prod \
     --member="serviceAccount:audio-storage-sa@learning-hebrew-1758491674.iam.gserviceaccount.com" \
     --role="roles/storage.objectAdmin"

   # Generate credentials key
   gcloud iam service-accounts keys create gcs-key.json \
     --iam-account=audio-storage-sa@learning-hebrew-1758491674.iam.gserviceaccount.com
   ```

4. **Add credentials to Google Secret Manager**
   ```bash
   # Upload GCS credentials
   gcloud secrets create gcs-credentials \
     --data-file=gcs-key.json \
     --project=learning-hebrew-1758491674

   # Grant access to GKE service account
   gcloud secrets add-iam-policy-binding gcs-credentials \
     --member="serviceAccount:github-actions@learning-hebrew-1758491674.iam.gserviceaccount.com" \
     --role="roles/secretmanager.secretAccessor"
   ```

5. **Update Kubernetes secrets**
   ```yaml
   # k8s/secrets-prod.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: learning-hebrew-secrets
     namespace: learning-hebrew
   type: Opaque
   data:
     gcs-credentials: <base64-encoded-json>
   ```

6. **Update deployment to mount GCS credentials**
   ```yaml
   # k8s/rails-app.yaml
   spec:
     containers:
     - name: learning-hebrew-app
       env:
       - name: GOOGLE_APPLICATION_CREDENTIALS
         value: /var/secrets/gcs/credentials.json
       volumeMounts:
       - name: gcs-credentials
         mountPath: /var/secrets/gcs
         readOnly: true
     volumes:
     - name: gcs-credentials
       secret:
         secretName: learning-hebrew-secrets
         items:
         - key: gcs-credentials
           path: credentials.json
   ```

7. **Update GitHub Actions workflow**
   ```yaml
   # .github/workflows/deploy.yml
   - name: Retrieve GCS credentials from Secret Manager
     run: |
       gcloud secrets versions access latest \
         --secret="gcs-credentials" \
         --format='get(payload.data)' | tr '_-' '/+' | base64 -d > gcs-key.json
       kubectl create secret generic learning-hebrew-secrets \
         --from-literal=gcs-credentials="$(cat gcs-key.json | base64)" \
         --namespace=learning-hebrew \
         --dry-run=client -o yaml | kubectl apply -f -
   ```

8. **Test in production**
   - Deploy updated application
   - Upload test audio file via UI
   - Verify file appears in GCS bucket
   - Test audio playback
   - Check application logs for errors

9. **Monitor costs**
   ```bash
   # Check bucket size
   gcloud storage du gs://learning-hebrew-audio-prod --summarize

   # Monitor storage costs (Cloud Console)
   # Billing > Reports > Filter by "Cloud Storage"
   ```

**Files Changed:**
- `k8s/secrets-prod.yaml`
- `k8s/rails-app.yaml`
- `.github/workflows/deploy.yml`

**Cost Estimates (as of 2024):**
- Standard Storage: $0.020/GB/month
- Class A Operations (uploads): $0.05 per 10,000 ops
- Class B Operations (downloads): $0.004 per 10,000 ops
- Expected: ~1GB audio = ~$0.02/month + minimal operation costs

---

## Implementation Checklist

### Phase 1: Infrastructure ✓
- [ ] Install Active Storage migrations
- [ ] Create GCS buckets (dev/prod)
- [ ] Configure storage.yml
- [ ] Add google-cloud-storage gem
- [ ] Create service account and credentials
- [ ] Test Active Storage in console

### Phase 2: Model Changes ✓
- [ ] Create migration for audio_identifier column
- [ ] Add audio_identifier generation logic to Word model
- [ ] Backfill existing words with audio_identifiers
- [ ] Add has_one_attached :audio_file to Word
- [ ] Add helper methods (audio_attached?, audio_url)
- [ ] Add validations
- [ ] Update factories with :with_audio trait
- [ ] Create sample audio test fixture

### Phase 3: UI Components ✓
- [ ] Create audio player partial
- [ ] Create Stimulus audio player controller
- [ ] Add audio player to word show page
- [ ] Add audio indicator to dictionary view
- [ ] Style with Tailwind CSS

### Phase 4: Manual Upload ✓
- [ ] Update word edit form with file upload
- [ ] Update WordsController to handle audio_file param
- [ ] Add remove_audio action and route
- [ ] Update WordPolicy if needed

### Phase 5: Bulk Import ✓
- [ ] Create AudioImportService (using audio_identifier lookup)
- [ ] Add CSV export action to ImportController
- [ ] Add import form to import page with export link
- [ ] Add import_audio action to ImportController
- [ ] Add rubyzip gem
- [ ] Test export CSV workflow
- [ ] Test with sample ZIP file

### Phase 6: Testing ✓
- [ ] Write model specs
- [ ] Write controller specs
- [ ] Write service specs
- [ ] Write system/feature specs
- [ ] Update CLAUDE.md
- [ ] Create user documentation

### Phase 7: Deployment ✓
- [ ] Create GCS buckets in production
- [ ] Configure CORS
- [ ] Create service account
- [ ] Add credentials to Secret Manager
- [ ] Update Kubernetes manifests
- [ ] Update GitHub Actions workflow
- [ ] Deploy and test in production

---

## Future Enhancements

### Short-term (Post-MVP)
1. **Multiple pronunciations per word**
   - Add `audio_identifier` column
   - Support multiple audio attachments (has_many_attached)
   - UI for selecting different pronunciations

2. **Audio recording in-app**
   - Use Web Audio API for in-browser recording
   - Direct upload from microphone

3. **Audio quality indicators**
   - Display bitrate, duration, file size
   - Warn about low-quality or oversized files

### Long-term
1. **Text-to-speech fallback**
   - Integrate Google Cloud TTS for missing audio
   - Generate audio on-demand for new words

2. **Audio waveform visualization**
   - Show visual playback progress
   - Interactive scrubbing

3. **Pronunciation practice**
   - Record user pronunciation
   - Compare with reference audio

4. **CDN optimization**
   - Cloud CDN for faster global delivery
   - Compression and optimization pipeline

---

## Risk Mitigation

### Storage Costs
- **Risk:** Thousands of audio files could incur unexpected costs
- **Mitigation:**
  - Monitor bucket size and costs via Cloud Console
  - Set up billing alerts at $5, $10, $20 thresholds
  - Use lifecycle policies to delete old/unused audio
  - Estimated cost for 10,000 words @ 60KB each = 600MB = $0.01/month

### Performance
- **Risk:** Loading many audio files could slow down pages
- **Mitigation:**
  - Lazy loading with `preload="none"`
  - Direct serving from GCS (not through Rails)
  - No eager loading of audio attachments
  - Optional: Add audio presence indicator (icon) without loading files

### Data Loss
- **Risk:** Losing audio files during migration or deployment
- **Mitigation:**
  - Bucket versioning enabled
  - Regular backups via `gcloud storage cp`
  - Test restore procedures
  - Keep original audio files as backup

### Browser Compatibility
- **Risk:** Audio format not supported on some browsers
- **Mitigation:**
  - MP3 has 99.9% browser support (all modern browsers)
  - Fallback message for unsupported browsers
  - Optional: Add OGG format as fallback (future enhancement)

---

## Success Metrics

### Technical Metrics
- Audio upload success rate > 95%
- Average audio load time < 500ms
- Storage costs < $5/month
- Zero N+1 queries related to audio
- 100% test coverage for audio features

### User Metrics
- % of words with audio attached
- Number of audio plays per session
- User feedback on audio quality
- Import success/failure rates

---

## Appendix

### Audio File Preparation Guide

**Recording recommendations:**
- Clear, native Hebrew pronunciation
- Minimal background noise
- 10 seconds or less per word
- Consistent volume across files

**Encoding settings:**
```bash
# Convert to web-optimized MP3
ffmpeg -i input.wav -codec:a libmp3lame -b:a 64k -ar 44100 -ac 1 output.mp3
```

**Manifest Generation Script:**
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

words_csv = ARGV[0]
audio_dir = ARGV[1]

unless words_csv && audio_dir
  puts "Usage: ruby generate_manifest.rb words.csv audio_dir/"
  exit 1
end

# Get list of audio files
audio_files = Dir.glob(File.join(audio_dir, '*.mp3')).map { |f| File.basename(f) }

puts "audio_identifier,filename"

CSV.foreach(words_csv, headers: true) do |row|
  hebrew = row['representation']
  gloss = row['gloss']

  hash = hash_hebrew(hebrew)

  # Try to match audio file by gloss
  matching_file = audio_files.find { |f| f.downcase.include?(gloss.downcase) }

  if matching_file
    puts "#{hash},#{matching_file}"
    STDERR.puts "Matched: #{hebrew} (#{gloss}) -> #{matching_file}"
  else
    STDERR.puts "WARNING: No audio file found for: #{hebrew} (#{gloss})"
  end
end
```

**Manual manifest creation:**
```bash
# If you already know your mappings, create manifest directly:
cat > manifest.csv <<EOF
audio_identifier,filename
e8f2a6d3c1b4,peace.mp3
7a3c5f1d8b2e,king_noun.mp3
9e2d4a6f3c1b,god.mp3
EOF
```

### Troubleshooting

**Audio not playing:**
1. Check browser console for errors
2. Verify audio file format (should be audio/mpeg)
3. Test signed URL directly in browser
4. Check GCS bucket permissions

**Import failures:**
1. Verify ZIP file structure (flat, no subdirectories)
2. Check filename format (must be `{audio_identifier}.mp3`, lowercase alphanumeric + hyphens)
3. Verify audio_identifiers exist in database (export CSV to confirm)
4. Check file size limits (< 5MB per file)

**Word re-import scenario:**
If you need to re-import words and reset database IDs:
1. Export audio identifiers CSV BEFORE re-import (backup)
2. Export all audio files from GCS bucket: `gsutil -m cp -r gs://learning-hebrew-audio-prod /backup/audio`
3. Re-import words - audio_identifiers will regenerate with same logic
4. If audio_identifiers changed, update your local audio files to match new identifiers
5. Re-upload audio ZIP with updated filenames
6. Audio associations maintained because audio_identifier is deterministic (based on transliteration + POS)

**Storage issues:**
1. Verify GCS credentials are mounted correctly
2. Check service account permissions
3. Test connection with `gsutil ls gs://bucket-name`
4. Review application logs for Active Storage errors

### References
- [Active Storage Overview](https://guides.rubyonrails.org/active_storage_overview.html)
- [Google Cloud Storage for Rails](https://cloud.google.com/ruby/getting-started/using-cloud-storage)
- [HTML5 Audio Element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/audio)
- [Stimulus.js Documentation](https://stimulus.hotwired.dev/)
