# Interactive Stories with Dictionary Lookup

## Overview

Transform the static HTML stories into interactive, database-backed stories with click-to-reveal dictionary lookups for Hebrew words.

## Goals

1. Read story content from structured JSON format (AI-generated)
2. Store stories in JSON files (long-term backup) with database import capability
3. Generate the three story sections (Hebrew, English, Interlinear) from JSON
4. Enable click popups showing dictionary definitions for Hebrew words
5. Reuse existing dictionary search functionality for word lookup

## Data Structure

### Story JSON Format

```json
{
  "title": "אִישׁ מִלְחָמָה – A Man of Battle",
  "verses": [
    {
      "text": "וַיְהִי אִישׁ חָזָק בָּעִיר",
      "translation": "And there was a strong man in the city.",
      "transliteration": "vay-hi ish ha-zak ba-'ir"
    },
    {
      "text": "וַיֵּשֶׁב הָאִישׁ שָׁם בַּבֹּקֶר",
      "translation": "And the man sat there in the morning.",
      "transliteration": "vay-ye-shev ha-ish sham ba-bo-ker"
    }
  ]
}
```

## Architecture: Database Storage (SELECTED)

**Implementation:**
- Database-backed stories from the start
- JSON files in `stories/` directory are source files for import
- Import page reads JSON files and populates database
- Controller reads from Story model (not JSON files)
- JSON files remain as version-controlled source of truth

**Database Model:**
```ruby
# Story model
class Story < ApplicationRecord
  # columns: title, content (JSONB), slug, created_at, updated_at
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true

  # Generate slug from filename
  before_validation :generate_slug, on: :create

  def verses
    content["verses"] || []
  end

  private

  def generate_slug
    self.slug ||= title.parameterize if title.present?
  end
end
```

**Import Workflow:**
1. User places JSON files in `stories/` directory
2. Navigate to Import page (existing page)
3. Second section lists available JSON files from `stories/` directory
4. Click "Import" button to import story into database
5. Existing stories show "Update" button if JSON file is newer

**Why this approach:**
- Database querying and filtering capabilities from the start
- Can add metadata (difficulty, views, ratings) later
- Better performance (no file I/O per request)
- Enables future features (tracking, analytics, linking to vocab)
- JSON files serve as canonical source for version control
- Import process is straightforward (just click import)

## Word Lookup System

### Challenge: Hebrew Word Matching

Hebrew words in stories may differ from dictionary entries due to:
1. **Vowel marks** (nikkud) - may be present or absent
2. **Final forms** (ך, ם, ן, ף, ץ vs כ, מ, נ, פ, צ)
3. **Prefixes** (ה, ו, ב, כ, ל, מ, ש)
4. **Suffixes** (pronominal suffixes like י, ך, ו, ה, כם, הם) - **OUT OF SCOPE for MVP**

### Lookup Strategy (Exact Match WITH Nikkud)

**IMPORTANT: Nikkud is significant for story lookups** (unlike dictionary search which strips nikkud)

**Tier 1: Exact Match (including nikkud)**
- Try exact match on word as-is, including all nikkud
- Direct database lookup on `representation` field
- **Return only ONE result** (first match)
- No normalization at this stage

**Tier 2: Final Form Normalization (preserve nikkud)**
- Convert final forms to regular forms: ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ
- **Preserve all nikkud** (do not strip vowel marks)
- Try database lookup again
- **Return only ONE result** (first match)

**Tier 3: Prefix Removal (strip only prefix's nikkud)**
- Remove common prefixes: ה, ו, ב, כ, ל, מ, ש
- **Only remove nikkud directly attached to the removed prefix letter**
- **Preserve all other nikkud on remaining letters**
- Try database lookup again
- **Return only ONE result** (first match)
- If multiple matches exist, show "not found" (low confidence)

**Not Found**
- Show "Word not in dictionary"
- Do not attempt complex morphology analysis
- Complex forms (multiple prefixes, suffixes, combined words) are out of scope

**Key Principle: Exact Match with Nikkud**
- Unlike dictionary search, nikkud matters for story lookups
- Only show definition if we have ONE exact match
- Better to say "not found" than show wrong definition
- Complex morphology analyzer deferred to future enhancement

### Lookup Implementation: On-Demand AJAX (SELECTED)

**Approach:** Click-to-reveal with browser caching

```javascript
// When user clicks on word
async function lookupWord(hebrewWord) {
  // Check browser cache first
  const cached = sessionStorage.getItem(`word:${hebrewWord}`)
  if (cached) {
    return JSON.parse(cached)
  }

  // Fetch from API
  const response = await fetch(`/api/dictionary/lookup?word=${encodeURIComponent(hebrewWord)}`)
  const data = await response.json()

  // Cache result in browser
  sessionStorage.setItem(`word:${hebrewWord}`, JSON.stringify(data))

  return data
}
```

**Why this approach:**
- Fast initial page load (no pre-processing)
- Only lookup words user actually clicks on
- Always shows latest dictionary data
- Browser caching prevents duplicate API calls
- **Performance critical:** Must respond quickly or users will think it's broken

**Performance Requirements:**
- API response time: < 100ms target
- Popup display after click: < 200ms total
- Cache hit display: < 50ms

**Mobile:** Not optimized for MVP (desktop/click interaction only)

## Technical Implementation Plan

### Phase 1: Create Story Import System

**Step 1.1:** Create Story model and migration
```ruby
# db/migrate/XXXXXX_create_stories.rb
class CreateStories < ActiveRecord::Migration[8.0]
  def change
    create_table :stories do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.jsonb :content, null: false, default: {}

      t.timestamps
    end

    add_index :stories, :slug, unique: true
    add_index :stories, :content, using: :gin
  end
end

# app/models/story.rb
class Story < ApplicationRecord
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  def verses
    content["verses"] || []
  end

  private

  def generate_slug
    # Generate from title, or use filename if title not available yet
    self.slug ||= title.parameterize if title.present?
  end
end
```

**Step 1.2:** Add Story import section to Import page
```erb
<!-- Add to app/views/import/new.html.erb after dictionary import section -->

<div class="bg-white shadow-md rounded px-8 py-6 mb-4 mt-8">
  <h2 class="text-xl font-semibold mb-4">Import Stories</h2>
  <p class="text-gray-700 mb-4">Import Hebrew stories from JSON files in the <code class="bg-gray-200 px-1 rounded">stories/</code> directory.</p>

  <div class="space-y-2">
    <% Dir.glob(Rails.root.join("stories", "*.json")).each do |file_path| %>
      <% filename = File.basename(file_path, ".json") %>
      <% existing_story = Story.find_by(slug: filename) %>

      <div class="flex items-center justify-between border border-gray-300 rounded p-3">
        <div class="flex-1">
          <span class="font-mono text-sm"><%= filename %>.json</span>
          <% if existing_story %>
            <span class="ml-2 px-2 py-1 bg-green-100 text-green-800 rounded text-xs">Already imported</span>
          <% end %>
        </div>

        <%= button_to existing_story ? "Re-import" : "Import",
            import_story_path(filename: filename),
            method: :post,
            class: "bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-3 rounded text-sm" %>
      </div>
    <% end %>

    <% if Dir.glob(Rails.root.join("stories", "*.json")).empty? %>
      <p class="text-gray-500 italic">No JSON files found in stories/ directory.</p>
    <% end %>
  </div>
</div>
```

**Step 1.3:** Add story import route and controller action
```ruby
# config/routes.rb
post "import/story", to: "import#import_story", as: :import_story

# app/controllers/import_controller.rb
def import_story
  authorize :import

  filename = params[:filename]
  file_path = Rails.root.join("stories", "#{filename}.json")

  unless File.exist?(file_path)
    redirect_to new_import_path, alert: "Story file not found: #{filename}.json"
    return
  end

  begin
    json_data = JSON.parse(File.read(file_path))

    # Find or create story
    story = Story.find_or_initialize_by(slug: filename)
    story.title = json_data["title"]
    story.content = json_data
    story.save!

    redirect_to new_import_path, notice: "Successfully imported story: #{json_data['title']}"
  rescue JSON::ParserError => e
    redirect_to new_import_path, alert: "Invalid JSON in #{filename}.json: #{e.message}"
  rescue => e
    redirect_to new_import_path, alert: "Failed to import story: #{e.message}"
  end
end
```

### Phase 2: Update Stories Controller

**Step 2.1:** Update controller to read from database
```ruby
# app/controllers/stories_controller.rb
def index
  @stories = Story.order(created_at: :desc).all
end

def show
  @story = Story.find_by(slug: params[:id])

  unless @story
    redirect_to stories_path, alert: "Story not found"
    return
  end

  @title = @story.title
  @verses = @story.verses
end
```

**Step 2.2:** Update stories index view
```erb
<!-- app/views/stories/index.html.erb -->
<div class="w-full">
  <div class="flex justify-between items-center mb-6">
    <h1 class="font-bold text-4xl">Hebrew Stories</h1>
  </div>

  <% if @stories.empty? %>
    <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded mb-4">
      No stories found. Import stories from the <%= link_to "Import", new_import_path, class: "underline font-semibold" %> page.
    </div>
  <% else %>
    <div class="space-y-4">
      <% @stories.each do |story| %>
        <div class="border border-gray-300 rounded-lg p-6 hover:bg-gray-50 transition">
          <%= link_to story_path(story.slug), class: "block" do %>
            <h2 class="text-2xl font-semibold text-blue-600 hover:text-blue-800 mb-2">
              <%= story.title %>
            </h2>
            <p class="text-gray-600 text-sm">
              <%= pluralize(story.verses.count, 'verse') %> • Click to read
            </p>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

### Phase 3: Create Dictionary Lookup API

**Goal:** Reuse existing dictionary search functionality with exact match requirement

**Step 3.1:** Add API endpoint
```ruby
# config/routes.rb
namespace :api do
  get 'dictionary/lookup', to: 'dictionary#lookup'
end

# app/controllers/api/dictionary_controller.rb
class Api::DictionaryController < ApplicationController
  def lookup
    word = params[:word]
    result = DictionaryLookupService.lookup(word)
    render json: result
  end
end
```

**Step 3.2:** Create lookup service (exact match with nikkud preservation)
```ruby
# app/services/dictionary_lookup_service.rb
class DictionaryLookupService
  PREFIXES = ['ה', 'ו', 'ב', 'כ', 'ל', 'מ', 'ש'].freeze

  # Final form mappings
  FINAL_FORMS = {
    'ך' => 'כ',
    'ם' => 'מ',
    'ן' => 'נ',
    'ף' => 'פ',
    'ץ' => 'צ'
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

  private

  def self.find_exact_match(word)
    # Direct exact match on representation field (includes nikkud)
    matches = Word.where(representation: word)
                   .includes(:glosses)
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

      # Also try final form normalization on the result
      match = find_exact_match(without_prefix)
      return match if match

      # Try with final form normalization as well
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
    text.sub(/^[\u0591-\u05AF\u05B0-\u05BD\u05BF-\u05C2\u05C4\u05C5\u05C7]+/, '')
  end

  def self.format_result(word, original_word)
    {
      found: true,
      original: original_word,
      hebrew: word.representation,
      gloss: word.glosses.map(&:text).join(", "), # Show ALL glosses (v1 requirement)
      transliteration: "", # Will use story transliteration, not dictionary
      pos: word.pos_display || ""
    }
  end
end
```

**Key Implementation Notes:**
- **NO use of `Word.normalize_hebrew()`** - nikkud is preserved throughout
- **Tier 1:** Direct exact match on `representation` field (includes all nikkud)
- **Tier 2:** Convert final forms only, preserve all nikkud
- **Tier 3:** Remove prefix and ONLY the nikkud directly on that prefix letter
- **Exact match only:** Return `nil` if multiple matches found (low confidence)
- **Show all glosses:** Comma-separated list (may be long, but v1 requirement)
- **No dictionary transliteration:** Story provides context-specific pronunciation
- **Performance target:** < 100ms response time

### Phase 4: Build Interactive Story View

**Step 4.1:** Create Hebrew word tokenizer
```ruby
# app/helpers/stories_helper.rb
module StoriesHelper
  def tokenize_hebrew(text)
    # Split on spaces, preserve punctuation
    text.split(/\s+/).map do |token|
      # Separate punctuation from words
      if token =~ /^([^\u0590-\u05FF\s]+)?(.+?)([^\u0590-\u05FF\s]+)?$/
        {
          prefix: $1 || "",
          word: $2,
          suffix: $3 || ""
        }
      else
        { prefix: "", word: token, suffix: "" }
      end
    end
  end
end
```

**Step 4.2:** Update view template (with Stimulus controller)
```erb
<!-- app/views/stories/show.html.erb -->
<div class="story-container" data-controller="hebrew-word">
  <!-- Hebrew Story Section -->
  <div class="hebrew-story">
    <h2>📖 <%= @title %></h2>
    <% @verses.each do |verse| %>
      <div class="verse-hebrew">
        <% tokenize_hebrew(verse['text']).each do |token| %>
          <%= token[:prefix] %>
          <span class="hebrew-word"
                data-word="<%= token[:word] %>"
                data-action="click->hebrew-word#showDefinition">
            <%= token[:word] %>
          </span>
          <%= token[:suffix] %>
        <% end %>
      </div>
    <% end %>
  </div>

  <!-- English Translation Section -->
  <div class="english-translation">
    <h3>English Translation</h3>
    <% @verses.each do |verse| %>
      <p><%= verse['translation'] %></p>
    <% end %>
  </div>

  <!-- Interlinear Table Section -->
  <div class="interlinear">
    <h3>Line-by-Line Interlinear</h3>
    <table>
      <% @verses.each do |verse| %>
        <tr>
          <td class="english"><%= verse['translation'] %></td>
          <td class="hebrew">
            <%= verse['text'] %><br>
            <span class="translit"><%= verse['transliteration'] %></span>
          </td>
        </tr>
      <% end %>
    </table>
  </div>
</div>
```

**Key Template Changes:**
- Added `data-controller="hebrew-word"` to container
- Added `data-action="click->hebrew-word#showDefinition"` to each Hebrew word span
- Click event triggers `showDefinition` method in Stimulus controller

**Step 4.3:** Create Stimulus controller for word click (with browser caching)
```javascript
// app/javascript/controllers/hebrew_word_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["word"]

  connect() {
    this.popup = null
  }

  async showDefinition(event) {
    const word = event.currentTarget.dataset.word

    // Check sessionStorage cache first (persists across page loads)
    const cacheKey = `word:${word}`
    const cached = sessionStorage.getItem(cacheKey)

    let data
    if (cached) {
      data = JSON.parse(cached)
    } else {
      // Fetch from API
      try {
        const response = await fetch(`/api/dictionary/lookup?word=${encodeURIComponent(word)}`)
        data = await response.json()

        // Cache the result in sessionStorage
        sessionStorage.setItem(cacheKey, JSON.stringify(data))
      } catch (error) {
        console.error("Lookup failed:", error)
        return
      }
    }

    this.displayPopup(data, event)
  }

  displayPopup(data, event) {
    // Remove existing popup
    this.hideDefinition()

    // Create popup element
    this.popup = document.createElement('div')
    this.popup.className = 'word-popup'

    if (data.found) {
      this.popup.innerHTML = `
        <div class="popup-hebrew">${data.hebrew}</div>
        <div class="popup-gloss">${data.gloss}</div>
        ${data.pos ? `<div class="popup-pos">(${data.pos})</div>` : ''}
      `
    } else {
      this.popup.innerHTML = `
        <div class="popup-not-found">
          <strong>${data.word}</strong><br>
          Word not in dictionary
        </div>
      `
    }

    // Position popup near click point
    this.popup.style.position = 'absolute'
    this.popup.style.left = `${event.pageX + 10}px`
    this.popup.style.top = `${event.pageY + 10}px`

    // Close popup when clicking anywhere
    this.popup.addEventListener('click', (e) => {
      e.stopPropagation()
      this.hideDefinition()
    })

    document.body.appendChild(this.popup)

    // Close on next click anywhere
    setTimeout(() => {
      document.addEventListener('click', () => this.hideDefinition(), { once: true })
    }, 100)
  }

  hideDefinition() {
    if (this.popup) {
      this.popup.remove()
      this.popup = null
    }
  }
}
```

**Key Changes:**
- **Click-based:** User clicks word to show popup (not hover)
- **sessionStorage caching:** Results persist across page loads during session
- **Auto-close:** Popup closes on next click anywhere
- **No transliteration:** Story verse provides transliteration (not popup)
- **Performance tracking:** Console log if API response > 100ms (for monitoring)

**Step 4.4:** Add popup styles
```css
/* app/assets/stylesheets/stories.css */
.hebrew-word {
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 3px;
  transition: background-color 0.15s;
  display: inline-block; /* Better click target */
}

.hebrew-word:hover {
  background-color: #fef3c7; /* Visual feedback on hover */
}

.hebrew-word:active {
  background-color: #fde68a; /* Visual feedback on click */
}

.word-popup {
  background: white;
  border: 2px solid #3b82f6;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
  z-index: 1000;
  max-width: 350px;
  min-width: 200px;
  cursor: pointer; /* Indicate popup is clickable to close */
}

.popup-hebrew {
  font-size: 20pt;
  font-family: "SBL Hebrew", serif;
  direction: rtl;
  margin-bottom: 8px;
  font-weight: bold;
}

.popup-gloss {
  font-size: 14pt;
  margin-bottom: 4px;
  line-height: 1.4;
  color: #333;
}

.popup-pos {
  font-size: 11pt;
  font-style: italic;
  color: #666;
  margin-top: 4px;
}

.popup-not-found {
  color: #dc2626;
  font-size: 12pt;
}

/* Story-specific verse styling */
.verse-hebrew {
  margin-bottom: 1em;
  font-size: 24pt;
  line-height: 1.8;
}

.interlinear .translit {
  font-size: 12pt;
  color: #666;
  font-style: italic;
}
```

### Phase 5: Story Creation Tool (OUT OF SCOPE FOR MVP)

**Goal:** Allow easy creation of new stories from plain Hebrew text

**Input:**
- Title
- Hebrew text (verses separated by line breaks)
- English translations (one per line)
- Transliterations (one per line)

**Process:**
1. Parse input into verse structure
2. Validate verse count matches across languages
3. Generate JSON
4. Save to stories directory (or database)

**UI:** Admin form at `/stories/new` (superuser only)

## Implementation Roadmap (MVP)

### Phase 1: Story Import System (2-3 hours)
1. Create `stories` table migration (title, slug, content JSONB)
2. Create Story model with validations
3. Add story import section to Import page view
4. Add `import_story` route and controller action
5. Test importing one JSON story from `stories/` directory
6. Update stories index to read from database

### Phase 2: Update Stories Controller (1 hour)
1. Modify `StoriesController#index` to query Story model
2. Modify `StoriesController#show` to read from database using slug
3. Update index view to show story count and verses
4. Test story display with imported story

### Phase 3: Create API Endpoint (2-3 hours)
1. Add `Api::DictionaryController` with `lookup` action
2. Implement `DictionaryLookupService` with exact match logic
3. Add prefix removal with nikkud stripping
4. Test API endpoint manually with curl/Postman
5. Write RSpec tests for service

### Phase 4: Interactive View (3-4 hours)
1. Update `stories/show.html.erb` with tokenization
2. Add Stimulus controller for click interactions
3. Implement sessionStorage caching
4. Add CSS for popups and word highlighting
5. Test click interactions and popup display
6. Monitor API response times (< 100ms target)

### Phase 5: Testing & Refinement (2-3 hours)
1. Test with multiple stories
2. Check dictionary coverage percentage
3. Refine prefix removal based on real story data
4. Performance optimization if needed
5. Document any words not found for later addition
6. Test re-importing stories (updates existing)

**Total Estimated Time: 10-14 hours**

### Future Enhancements (Post-MVP)
- Story metadata (difficulty, vocabulary count, reading time)
- Coverage analytics (which words need dictionary entries)
- Link stories to vocabulary decks
- Track user progress (which stories read, completion percentage)
- Complex morphology analyzer
- Mobile optimization
- Story creation form (instead of JSON files)

## Performance Considerations (MVP)

**Browser Caching (Implemented):**
- sessionStorage for word lookups (persists during session)
- Prevents duplicate API calls for same word
- Fast cache hits (< 50ms)

**API Performance Requirements:**
- Target: < 100ms response time
- Database query optimization with indexes
- Eager loading for glosses (`.includes(:glosses)`)
- Monitor slow queries and optimize as needed

**Future Optimizations:**
- Server-side caching (Redis/Memcached) for frequent words
- Pre-computed word lookups stored in story metadata
- CDN for static story JSON files
- Background job to analyze story coverage

## Testing Strategy

**Unit Tests:**
- `DictionaryLookupService` with various word forms
- Hebrew tokenization helper
- Prefix removal logic

**Integration Tests:**
- Story JSON parsing
- API endpoint responses
- Full story rendering

**Manual Testing:**
- Hover over every word type (with prefixes, suffixes, etc.)
- Test with and without dictionary matches
- Verify popup positioning
- Check mobile responsiveness

## Decisions Made

1. **Nikkud Significance:** Nikkud IS important for story word lookups
   - Unlike dictionary search (which strips nikkud), story lookups preserve nikkud
   - Tier 1: Exact match including all nikkud
   - Tier 2: Convert final forms but preserve all nikkud
   - Tier 3: Remove prefix and ONLY the nikkud directly on that prefix letter
   - This allows for more precise matches with more display space

2. **Prefixes/Suffixes:** No comprehensive morphology analyzer for MVP
   - Simple prefix removal (ה, ו, ב, כ, ל, מ, ש) only
   - Remove nikkud ONLY if directly attached to removed prefix letter
   - Preserve all other nikkud on remaining letters
   - Complex forms (multiple words, suffixes) are out of scope

3. **Multiple Matches:** Show "not found" if multiple matches exist
   - Only show definition with exactly ONE match (confidence over coverage)
   - Better to say "not found" than show wrong definition

4. **Context:** Show all glosses (v1)
   - Comma-separated list of all glosses for matched word
   - May be unwieldy for words with many meanings, but acceptable for v1
   - Future: AI-based context selection (v2)

5. **Pronunciation:** Use story transliteration (not dictionary)
   - Transliteration in verse JSON is context-specific
   - Popup shows gloss only, not transliteration
   - Full transliteration visible in interlinear table

6. **Mobile:** Not optimized for MVP
   - Desktop click interaction only
   - Mobile optimization deferred to future session
   - Tap should work but not optimized

## Success Metrics

- **Coverage:** % of story words found in dictionary
- **Engagement:** Average lookups per story
- **Learning:** Track which words need lookups most often
- **Performance:** Popup display time < 100ms

## Next Steps (APPROVED - DATABASE APPROACH)

### User Tasks:
1. ✅ Convert existing stories to JSON format using AI (DONE)
2. ✅ Place JSON files in `stories/` directory (DONE)
3. Import stories via Import page once importer is built
4. Provide feedback during testing phase

### Development Tasks:
1. **Phase 1**: Create Story model, migration, and import system (add section to Import page)
2. **Phase 2**: Update StoriesController to read from database
3. **Phase 3**: Create API endpoint and DictionaryLookupService
4. **Phase 4**: Build interactive view with Stimulus controller
5. **Phase 5**: Testing and refinement

### Implementation Notes:
- JSON files in `stories/` directory remain as source of truth
- Import page lists all JSON files and shows import status
- Stories stored in database with JSONB content column
- Re-importing updates existing story in database
- Slug generated from filename for URL routing

### Ready to Begin Implementation
