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

**Status:** ✅ COMPLETED

---

## Phase 2: Update Stories Controller (1 hour)

**Goal:** Complete database transition and improve story display

- [ ] **Step 2.1:** Refine StoriesController
  - [ ] Add error handling for missing stories
  - [ ] Add authorization checks if needed
  - [ ] Optimize queries with any needed includes

- [ ] **Step 2.2:** Polish stories index view
  - [ ] Style story cards with Tailwind
  - [ ] Add metadata display (verse count, etc.)
  - [ ] Add navigation back to main site

- [ ] **Testing & Verification**
  - [ ] Run full test suite
  - [ ] Verify UI looks good
  - [ ] Test navigation flows

**Status:** Not Started

---

## Phase 3: Create Dictionary Lookup API (2-3 hours)

**Goal:** Build API endpoint for Hebrew word lookups with exact match logic

- [ ] **Step 3.1:** Create API namespace and controller
  - [ ] Add `namespace :api` to routes
  - [ ] Add `get 'dictionary/lookup'` route
  - [ ] Create `app/controllers/api/dictionary_controller.rb`
  - [ ] Create `lookup` action returning JSON

- [ ] **Step 3.2:** Create DictionaryLookupService
  - [ ] Create `app/services/dictionary_lookup_service.rb`
  - [ ] Implement Tier 1: Exact match (with nikkud)
  - [ ] Implement Tier 2: Final form normalization (preserve nikkud)
  - [ ] Implement Tier 3: Prefix removal (strip only prefix nikkud)
  - [ ] Add `PREFIXES` constant: ה, ו, ב, כ, ל, מ, ש
  - [ ] Add `FINAL_FORMS` mapping: ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ
  - [ ] Return formatted result with found/not found status

- [ ] **Step 3.3:** Write service tests
  - [ ] Create `spec/services/dictionary_lookup_service_spec.rb`
  - [ ] Test exact matches with nikkud
  - [ ] Test final form normalization
  - [ ] Test prefix removal
  - [ ] Test not found cases
  - [ ] Test multiple match rejection

- [ ] **Testing & Verification**
  - [ ] Run full test suite
  - [ ] Test API endpoint manually with curl
  - [ ] Verify response times < 100ms

**Status:** Not Started

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
- [ ] Phase 2: Update Stories Controller
- [ ] Phase 3: Create Dictionary Lookup API
- [ ] Phase 4: Build Interactive Story View
- [ ] Phase 5: Testing & Refinement

---

## Notes

- JSON files in `stories/` directory remain source of truth
- Database provides runtime storage and query capabilities
- Stories use slug-based URLs (e.g., `/stories/shepherd-and-the-man`)
- Word lookups preserve nikkud (unlike dictionary search which strips it)
- Performance target: API response < 100ms, popup display < 200ms
