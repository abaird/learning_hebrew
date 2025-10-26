# Interactive Stories Implementation Progress

This file tracks the implementation progress of the Interactive Stories feature as described in `interactive_stories.md`.

## Implementation Workflow

For each phase:
1. ✅ Implement all tasks in the phase
2. ✅ Run full test suite and fix failures
3. ✅ Request user verification
4. ✅ Run Rubocop and fix issues
5. ✅ Update this file with completion status
6. ✅ Create commit and push after approval

---

## Phase 1: Story Import System (2-3 hours)

**Goal:** Create database-backed story import system with JSON source files

- [x] **Step 1.1:** Create Story model and migration
  - [x] Generate migration for `stories` table
    - [x] `title` (string, required)
    - [x] `slug` (string, required, unique index)
    - [x] `content` (JSONB, required, default: {})
    - [x] GIN index on `content` column
    - [x] timestamps
  - [x] Create `app/models/story.rb`
    - [x] Add validations (title, content, slug presence)
    - [x] Add `before_validation :generate_slug` callback
    - [x] Add `verses` method to extract verses from content
  - [x] Run migration

- [x] **Step 1.2:** Add Story import section to Import page
  - [x] Update `app/views/import/new.html.erb`
  - [x] Add "Import Stories" section after dictionary import
  - [x] List all JSON files from `stories/` directory
  - [x] Show "Already imported" status for existing stories
  - [x] Add Import/Re-import buttons for each file

- [x] **Step 1.3:** Add story import route and controller action
  - [x] Add `post "import/story"` route to `config/routes.rb`
  - [x] Add `import_story` action to `ImportController`
    - [x] Authorize with Pundit
    - [x] Read JSON file from stories/ directory
    - [x] Parse JSON and create/update Story record
    - [x] Handle errors (file not found, invalid JSON)
    - [x] Redirect with success/error message

- [x] **Step 1.4:** Update StoriesController for database
  - [x] Modify `StoriesController#index`
    - [x] Query `Story.order(created_at: :desc).all`
    - [x] Remove HTML file reading logic
  - [x] Modify `StoriesController#show`
    - [x] Find story by slug: `Story.find_by(slug: params[:id])`
    - [x] Extract verses from story.content
    - [x] Handle story not found

- [x] **Step 1.5:** Update stories views
  - [x] Update `app/views/stories/index.html.erb`
    - [x] Show database-backed stories
    - [x] Display story count and verse count
    - [x] Show "No stories" message with Import link
  - [x] Update `app/views/stories/show.html.erb` to work with new data structure

- [x] **Testing & Verification**
  - [x] Run full test suite: `bundle exec rspec`
  - [x] All tests passing (301 examples, 0 failures, 10 pending)
  - [x] Test importing shepherd_and_the_man.json via Rails console
  - [x] Verify story created successfully with 14 verses
  - [x] Migration completed for development and test environments
  - [x] User verified: Import functionality working correctly
  - [x] User verified: Stories display correctly on show page
  - [x] Fixed: Added `import_story?` method to ImportPolicy (superuser only)
  - [x] Rubocop: No style violations detected

**Status:** ✅ COMPLETED

**Files Changed:**
- `db/migrate/20251026204115_create_stories.rb` - Created stories table
- `app/models/story.rb` - Created Story model
- `app/views/import/new.html.erb` - Added story import section
- `config/routes.rb` - Added import_story route
- `app/controllers/import_controller.rb` - Added import_story action
- `app/controllers/stories_controller.rb` - Updated to use database
- `app/views/stories/index.html.erb` - Updated for database-backed stories
- `app/views/stories/show.html.erb` - Updated to display JSON-based verses
- `app/policies/import_policy.rb` - Added import_story? authorization

---

## Phase 2: Update Stories Controller (1 hour)

**Goal:** Complete database transition and improve story display

- [x] **Step 2.1:** Refine StoriesController
  - [x] Error handling for missing stories (already implemented in Phase 1)
  - [x] Authorization with `authenticate_user!` (already implemented)
  - [x] Query optimization (simple queries, no N+1 issues)

- [x] **Step 2.2:** Polish stories index view
  - [x] Style story cards with Tailwind (already implemented in Phase 1)
  - [x] Metadata display shows verse count (already implemented)
  - [x] Added "Back to Dictionary" navigation link

- [x] **Testing & Verification**
  - [x] Run full test suite: All tests passing (301 examples, 0 failures)
  - [x] UI is well-styled and functional
  - [x] Navigation flows verified

**Status:** ✅ COMPLETED

**Note:** Most Phase 2 requirements were already completed during Phase 1 implementation.
Only addition was "Back to Dictionary" link on stories index page.

**Files Changed:**
- `app/views/stories/index.html.erb` - Added navigation back to dictionary

---

## Phase 3: Create Dictionary Lookup API (2-3 hours)

**Goal:** Build API endpoint for Hebrew word lookups with exact match logic

- [x] **Step 3.1:** Create API namespace and controller
  - [x] Add `namespace :api` to routes
  - [x] Add `get 'dictionary/lookup'` route
  - [x] Create `app/controllers/api/dictionary_controller.rb`
  - [x] Create `lookup` action returning JSON

- [x] **Step 3.2:** Create DictionaryLookupService
  - [x] Create `app/services/dictionary_lookup_service.rb`
  - [x] Implement Tier 1: Exact match (with nikkud)
  - [x] Implement Tier 2: Final form normalization (preserve nikkud)
  - [x] Implement Tier 3: Prefix removal (strip only prefix nikkud)
  - [x] Add `PREFIXES` constant: ה, ו, ב, כ, ל, מ, ש
  - [x] Add `FINAL_FORMS` mapping: ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ
  - [x] Return formatted result with found/not found status

- [x] **Step 3.3:** Write service tests
  - [x] Create `spec/services/dictionary_lookup_service_spec.rb`
  - [x] Test exact matches with nikkud (16 comprehensive tests)
  - [x] Test final form normalization
  - [x] Test prefix removal
  - [x] Test not found cases
  - [x] Test multiple match rejection

- [x] **Testing & Verification**
  - [x] Run full test suite: All tests passing (317 examples, 0 failures)
  - [x] Test service manually with Rails runner
  - [x] Verified lookup returns correct JSON format

**Status:** ✅ COMPLETED

**Files Changed:**
- `app/controllers/api/dictionary_controller.rb` - API controller for lookups
- `app/services/dictionary_lookup_service.rb` - Three-tier lookup service
- `config/routes.rb` - Added API namespace and lookup route
- `spec/services/dictionary_lookup_service_spec.rb` - Comprehensive test suite (16 examples)

---

## Phase 4: Build Interactive Story View (3-4 hours)

**Goal:** Add click-to-reveal dictionary popups with Stimulus

- [ ] **Step 4.1:** Create Hebrew tokenizer helper
  - [ ] Add `tokenize_hebrew` method to `app/helpers/stories_helper.rb`
  - [ ] Split text on spaces, preserve punctuation
  - [ ] Return tokens with prefix/word/suffix structure

- [ ] **Step 4.2:** Update story show view
  - [ ] Update `app/views/stories/show.html.erb`
  - [ ] Add `data-controller="hebrew-word"` to container
  - [ ] Tokenize Hebrew verses and wrap words in spans
  - [ ] Add `data-word` and `data-action="click->hebrew-word#showDefinition"` to each word
  - [ ] Keep English translation section
  - [ ] Keep interlinear table section

- [ ] **Step 4.3:** Create Stimulus controller
  - [ ] Create `app/javascript/controllers/hebrew_word_controller.js`
  - [ ] Implement `showDefinition(event)` method
  - [ ] Add sessionStorage caching for lookups
  - [ ] Implement `displayPopup(data, event)` method
  - [ ] Position popup near click point
  - [ ] Implement `hideDefinition()` for cleanup
  - [ ] Add click-anywhere-to-close behavior

- [ ] **Step 4.4:** Add CSS styles
  - [ ] Create `app/assets/stylesheets/stories.css` or add to existing
  - [ ] Style `.hebrew-word` (cursor, hover, active states)
  - [ ] Style `.word-popup` (border, shadow, positioning)
  - [ ] Style `.popup-hebrew`, `.popup-gloss`, `.popup-pos`
  - [ ] Style `.popup-not-found`
  - [ ] Style `.verse-hebrew` and `.interlinear`

- [ ] **Testing & Verification**
  - [ ] Run full test suite
  - [ ] Test clicking on various Hebrew words
  - [ ] Verify popup display and positioning
  - [ ] Verify sessionStorage caching works
  - [ ] Test words with prefixes
  - [ ] Test words not in dictionary
  - [ ] Verify popup closes on click

**Status:** Not Started

---

## Phase 5: Testing & Refinement (2-3 hours)

**Goal:** End-to-end testing and optimization

- [ ] **Step 5.1:** Comprehensive testing
  - [ ] Test with all available stories
  - [ ] Test word lookup coverage
  - [ ] Identify common words not found
  - [ ] Test re-importing stories

- [ ] **Step 5.2:** Performance optimization
  - [ ] Monitor API response times
  - [ ] Optimize slow queries if needed
  - [ ] Test with large stories

- [ ] **Step 5.3:** Documentation
  - [ ] Document any words that need dictionary entries
  - [ ] Update CLAUDE.md with new features
  - [ ] Document story JSON format expectations

- [ ] **Testing & Verification**
  - [ ] Final full test suite run
  - [ ] Manual testing of complete user flow
  - [ ] Verify mobile experience (basic check)

**Status:** Not Started

---

## Completion Status

- [x] Phase 1: Story Import System ✅
- [x] Phase 2: Update Stories Controller ✅
- [x] Phase 3: Create Dictionary Lookup API ✅
- [ ] Phase 4: Build Interactive Story View
- [ ] Phase 5: Testing & Refinement

---

## Notes

- JSON files in `stories/` directory remain source of truth
- Database provides runtime storage and query capabilities
- Stories use slug-based URLs (e.g., `/stories/shepherd-and-the-man`)
- Word lookups preserve nikkud (unlike dictionary search which strips it)
- Performance target: API response < 100ms, popup display < 200ms
