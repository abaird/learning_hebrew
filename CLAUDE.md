# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hebrew learning application built with Ruby on Rails 8, featuring a flexible many-to-many vocabulary structure:
- Users create multiple Decks (vocabulary collections)
- Words (Hebrew vocabulary) can belong to multiple Decks
- Each Word has multiple Glosses (translations/definitions)
- Superuser functionality for administrative access

## Development Commands

### Local Development
```bash
# Start development server with CSS watch
bin/dev

# Start Rails server only
bin/rails server

# Start Rails console
bin/rails console

# Generate new migrations
bin/rails generate migration MigrationName

# Run database migrations
bin/rails db:migrate

# Reset database
bin/rails db:reset
```

### Docker Development
```bash
# Start services (PostgreSQL + Rails app)
docker-compose -f docker-compose.dev.yml up

# Run Rails commands in container
docker-compose -f docker-compose.dev.yml exec web bin/rails console
```

### Kubernetes Deployment

#### Quick Environment Switching
```bash
# Switch to development (minikube) - auto-starts port forwarding
script/dev.sh

# Switch to production (GKE) - stops port forwarding for safety
script/prod.sh
```

#### Production (GKE)
```bash
# Manual context switching (or use script/prod.sh)
kubectl config use-context gke_learning-hebrew-1758491674_us-central1_learning-hebrew-cluster

# Deploy to production
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n learning-hebrew
kubectl get ingress -n learning-hebrew

# View logs
kubectl logs -f deployment/learning-hebrew-app -n learning-hebrew

# Check deployment info (includes Git SHA, build number, etc.)
curl https://learning-hebrew.bairdsnet.net/up
```

#### Local Development (minikube)
```bash
# Bootstrap from scratch (recommended for fresh setup)
script/bootstrap.sh

# Manual context switching (or use script/dev.sh)
kubectl config use-context minikube

# Set Docker environment for minikube
eval $(minikube docker-env)

# Build local image (note: use 'local' tag)
docker build -t learning-hebrew:local .

# Toggle to local images (use script)
./script/toggle-image.sh

# Deploy to minikube (excluding production secrets)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets-local.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/local/rails-app-local.yaml
kubectl apply -f k8s/ingress.yaml

# Port forward for local access (or done automatically by script/dev.sh)
kubectl port-forward service/learning-hebrew-service 3000:80 -n learning-hebrew
```

### Testing

#### Local Testing (Minikube)
```bash
# Run all tests in proper test environment (minikube)
script/test.sh

# Run specific test files
script/test.sh spec/requests/decks_spec.rb

# Run with RSpec options
script/test.sh --format documentation

# Manual testing setup (if needed)
kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- \
  env RAILS_ENV=test DATABASE_URL="postgresql://..." bundle exec rspec
```

#### Local Testing (Traditional)
```bash
# Run RSpec test suite (requires local PostgreSQL)
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

**Note**: The `script/test.sh` approach is recommended as it:
- Runs tests in proper `test` environment (not development)
- Uses separate `learning_hebrew_test` database
- Provides test data isolation from development work
- Automatically handles database setup and cleanup

### Code Quality
```bash
# Run Rubocop linter
bundle exec rubocop

# Auto-fix Rubocop issues
bundle exec rubocop -A

# Run Brakeman security scanner
bundle exec brakeman
```

## Helper Scripts

The `script/` directory contains convenience scripts for common development tasks:

### Environment Management
```bash
# Switch to development environment (minikube + auto port-forward)
script/dev.sh

# Switch to production environment (GKE - no auto port-forward for safety)
script/prod.sh
```

### Deployment Tools
```bash
# Open Rails app in browser (auto-starts port forwarding if needed)
script/open.sh

# Start port forwarding manually
script/port-forward.sh [port]  # defaults to 3000

# Stop port forwarding
script/stop-port-forward.sh

# View application logs
script/logs.sh

# Toggle between local/production Docker images in k8s manifests
script/toggle-image.sh
```

### Testing Tools
```bash
# Run tests in minikube test environment (recommended)
script/test.sh

# Run specific test files
script/test.sh spec/requests/decks_spec.rb

# Run tests with RSpec options
script/test.sh --format documentation --color

# Verify CSS deployment and styling
script/test-css.sh
```

### Git Integration
- **Pre-push hook**: Automatically runs Rubocop and Brakeman before `git push` to prevent CI failures
  - Rubocop checks code style and best practices
  - Brakeman scans for security vulnerabilities
- **Override**: Use `git push --no-verify` to skip checks if needed (not recommended)
- **Auto-fix suggestion**: Hook provides `bundle exec rubocop -A` command when style violations found
- **Hook location**: `~/.git_template.local/hooks/pre-push` (symlinked from dotfiles)

## Architecture

### Database Schema
- **users**: Devise authentication (email, password, superuser)
- **decks**: Named collections belonging to users (name, description, user_id)
- **words**: Hebrew vocabulary items with lexeme/form relationships
  - Core fields: representation, part_of_speech_category_id, mnemonic, pronunciation_url, picture_url
  - Lexeme system: lexeme_id (self-referential for word forms)
  - Dictionary filtering: is_dictionary_entry (boolean with index for fast filtering)
  - JSONB metadata: form_metadata (binyan, conjugation, number, status, gender, etc.) with GIN index
- **deck_words**: Join table for many-to-many relationship (deck_id, word_id) with unique constraint
- **glosses**: Translation definitions (text, word_id)
- **part_of_speech_categories**: Standardized POS types (Verb, Noun, Adjective, etc.)
- **genders**: Gender categories (legacy table, no longer used - gender stored in JSONB metadata)
- **verb_forms**: Verb form types (legacy table, no longer used - binyan stored in JSONB metadata)

### Database Configuration
- **Development**: `learning_hebrew_development` - for local development work
- **Test**: `learning_hebrew_test` - isolated test environment with automatic cleanup
- **Production**: `learning_hebrew_production` - production data with strong security
- **Host Detection**: Automatically uses `localhost` for local development, `db` for containerized environments
- **Environment Variables**: `DATABASE_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `DATABASE_NAME` control connection settings (no hardcoded DATABASE_URL)

### Model Relationships
```
User (1) → Decks (many)
Words (many) ↔ Decks (many) [via DeckWord join table]
Words (1) → Glosses (many)
Word (lexeme) → Words (forms) [self-referential via lexeme_id]
Word → PartOfSpeechCategory
```

**Key Features:**
- **Lexeme/Form System**: Words can link to parent lexemes via `lexeme_id` (e.g., plural → singular, conjugations → infinitive)
- **Dictionary Entry Logic**: `is_dictionary_entry?` method determines which words appear in dictionary listings based on POS-specific rules
- **Hebrew Keyboard**: Interactive on-screen keyboard with SIL layout for users without Hebrew input
- **Smart Search**: Intelligent Hebrew search with automatic normalization of vowels, cantillation marks, and final forms
- **JSONB Metadata**: Flexible `form_metadata` column stores grammatical information (binyan, conjugation, number, status, etc.)
- **GIN Index**: Fast JSONB queries for filtering by metadata fields
- **Eager Loading**: Optimized queries prevent N+1 issues (includes :glosses, :decks, :part_of_speech_category)
- **Hebrew Sorting**: Custom alphabetical sorting by Hebrew alphabet order with vowel marks
- Many-to-many relationship between Decks and Words allows flexible vocabulary organization
- Superuser functionality with environment-aware database seeds
- Authorization with Pundit for role-based access control
- Modern UI with Tailwind CSS and responsive navigation
- Comprehensive test coverage with proper fixture management (301 examples, 0 failures)

### Key Technologies
- **Rails 8.0** with modern defaults
- **PostgreSQL** database
- **Devise** for authentication with customized views
- **Pundit** for authorization and role-based access control
- **Tailwind CSS** for styling with responsive design
- **Turbo/Stimulus** for frontend interactivity
- **RSpec** for testing
- **Docker** for containerized development

### File Structure
- `app/models/`: ActiveRecord models with validations and associations
- `app/controllers/`: RESTful controllers for decks, words, glosses with Pundit authorization
- `app/policies/`: Pundit authorization policies for role-based access control
- `app/views/`: ERB templates organized by controller with Tailwind CSS styling
- `app/views/devise/`: Customized Devise authentication views
- `app/views/layouts/`: Application layout with responsive navigation header
- `db/migrate/`: Database migration files
- `config/routes.rb`: Defines RESTful routes for all resources
- `spec/`: RSpec test suite with comprehensive coverage
- `projects/lexeme_project.md`: Detailed design doc for lexeme/form system implementation

### Lexeme/Form System

The application implements a sophisticated lexeme/form system for Hebrew words:

**Core Concepts:**
- **Lexeme**: The dictionary entry form of a word (e.g., 3MS verb, singular noun)
- **Form**: A grammatical variation of a lexeme (e.g., plural, different conjugation)
- **Self-Referential Association**: Forms link to their parent lexeme via `lexeme_id`

**Dictionary Entry Rules** (POS-specific):
- **Verbs**: Only 3MS (3rd person masculine singular) are dictionary entries
- **Nouns**: Only singular forms in absolute state (not construct)
- **Adjectives**: Only masculine singular forms
- **Participles**: Only masculine singular active forms
- **Pronouns/Prepositions/etc.**: All are dictionary entries (each is distinct)

**JSONB Metadata Fields** (`form_metadata` column):
- **Verb fields**: root, binyan, aspect, conjugation, person, weakness
- **Noun/Adjective fields**: number, status, gender, specific_type
- **Import fields**: pos_type, lesson_introduced, function
- **General fields**: notes, transliteration, variant_type

**Key Methods:**
- `is_dictionary_entry?`: Determines if word should appear in dictionary
- `parent_word`: Returns lexeme if form, otherwise self
- `form_description`: Describes grammatical features
- `hebrew_sort_key`: Custom Hebrew alphabetical sorting

**Search & Filtering**:
- Filter by text search (representation or glosses) with intelligent normalization
  - Automatically strips vowels, cantillation marks, and normalizes final forms
  - Searches are diacritic-insensitive for better Hebrew text matching
- Filter by POS, binyan, number
- Filter by lesson (exact or cumulative "or less" mode)
- Toggle to show all words vs. dictionary entries only (defaults to "show all")
- Interactive Hebrew keyboard component for users without Hebrew input capability

**Import System**:
- Supports both text format and JSON format
- JSON format includes metadata and lexeme linking via `lexeme_of_hint`
- Automatically merges POS details into JSONB `form_metadata`

**Performance Optimizations**:
- `is_dictionary_entry` boolean column with index for fast SQL filtering (replaces Ruby-level filtering)
- Dictionary controller filters in SQL before loading to memory (major performance improvement)
- GIN index on `form_metadata` for fast JSONB queries
- Eager loading prevents N+1 queries (`:glosses`, `:decks`, `:part_of_speech_category`)
- Automatic callback (`before_save :set_dictionary_entry_flag`) keeps column in sync with logic

## Development Environment

The application supports multiple development approaches:

**Local**: Requires PostgreSQL, Ruby, and Node.js. Uses `bin/dev` to start Rails server and Tailwind CSS watcher.

**Docker**: Complete environment with PostgreSQL container. Database connection configured for container networking (host: `db`).

**Kubernetes**:
- **Production**: Deployed on Google Kubernetes Engine (GKE) with CI/CD via GitHub Actions
- **Local**: minikube for testing Kubernetes configurations locally before production deployment
- **Testing**: Separate test database (`learning_hebrew_test`) with proper environment isolation

### CSS & Asset Compilation

The development environment uses a dual-process setup via Foreman to enable live CSS updates without Docker rebuilds.

**Procfile.dev Configuration:**
```
web: bin/rails server -b 0.0.0.0 -p 3000
css: ./bin/rails tailwindcss:build && while true; do sleep 5 && ./bin/rails tailwindcss:build 2>/dev/null; done
```

**How It Works:**
- Foreman runs both Rails server and CSS builder simultaneously
- CSS process rebuilds Tailwind every 5 seconds via polling loop
- Tilt syncs file changes from local machine to container instantly
- Propshaft serves updated CSS files from `app/assets/builds/tailwind.css`
- Browser refresh loads new styles (no automatic reload)

**Development Workflow for CSS Changes:**
1. Edit `app/assets/stylesheets/application.css` or `app/assets/tailwind/application.css`
2. Tilt syncs file to container (instant)
3. CSS builder detects change and rebuilds (within 5 seconds)
4. Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+R)
5. Changes appear - **no Docker rebuild needed!**

**Asset Configuration:**
- **Dockerfile.dev**: Does NOT precompile assets (allows live updates)
- **Dockerfile (production)**: DOES precompile assets at build time (line 56)
- **Layout**: Explicitly loads both Tailwind and application CSS files
  ```erb
  <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  ```

**Testing CSS Deployment:**
```bash
# Verify CSS is properly deployed and serving
script/test-css.sh
```

The test script validates:
- Homepage loads successfully
- Stylesheet links present in HTML
- CSS files serve valid content (not 404s)
- Tailwind utility classes are defined in CSS
- Tailwind file is substantial size (20KB+)
- Custom font classes are defined
- HTML classes have corresponding CSS definitions

**Troubleshooting:**
- If CSS doesn't update: Check container logs for build errors
  ```bash
  kubectl logs -f deployment/learning-hebrew-app -n learning-hebrew | grep css
  ```
- If builds take longer than 5 seconds: Check file permissions or disk I/O
- For immediate rebuild: `kubectl exec deployment/learning-hebrew-app -n learning-hebrew -- bin/rails tailwindcss:build`

## Deployment Architecture

### Production (GKE)
- **Cluster**: `learning-hebrew-cluster` in `us-central1`
- **Registry**: Google Artifact Registry (`us-central1-docker.pkg.dev/learning-hebrew-1758491674/learning-hebrew/learning-hebrew`)
- **Database**: PostgreSQL with persistent volumes
- **SSL**: Managed certificates via Google Cloud Load Balancer
- **CI/CD**: GitHub Actions workflow triggers on main branch push

### Local Testing (minikube)
- **Purpose**: Test Kubernetes configurations and code changes locally
- **Images**: Local Docker images with `imagePullPolicy: Never`
- **Secrets**: Separate local secrets file (gitignored)
- **Access**: Port forwarding for development testing

## Security & Secrets Management

### Google Secret Manager
All production secrets are stored securely in Google Secret Manager:
```bash
# View secrets
gcloud secrets list

# Get secret value
gcloud secrets versions access latest --secret="secret-name"

# Update secret (creates new version)
echo -n "new_value" | gcloud secrets versions add secret-name --data-file=-
```

**Secrets stored:**
- `postgres-user`: Database username
- `postgres-password`: Strong generated database password
- `rails-master-key`: Rails credentials encryption key
- `secret-key-base`: Rails session encryption key

**Security Features:**
- Secrets never stored in git (only placeholders)
- Automatic injection during CI/CD deployment
- Separate local secrets for development (gitignored)
- Free tier usage (4 secrets well within 6/month limit)

### Deployment Diagnostics

Enhanced `/up` health check endpoint provides deployment information:

```bash
# Check health and deployment info
curl https://learning-hebrew.bairdsnet.net/up

# Example response:
{
  "status": "ok",
  "timestamp": "2025-09-27T19:06:22Z",
  "environment": "production",
  "rails_version": "8.0.2.1",
  "ruby_version": "3.3.3",
  "database": {
    "adapter": "PostgreSQL",
    "connected": true
  },
  "deployment": {
    "git_sha": "abc123...",          # Actual commit SHA
    "build_number": "42",            # GitHub Actions run number
    "deployed_at": "2025-09-27T...", # Deployment timestamp
    "image_tag": "abc123..."         # Docker image tag
  }
}
```

**Useful diagnostic commands:**
```bash
# Get current Git SHA in production
curl -s https://learning-hebrew.bairdsnet.net/up | jq .deployment.git_sha

# Check database connectivity
curl -s https://learning-hebrew.bairdsnet.net/up | jq .database.connected

# View environment info
curl -s https://learning-hebrew.bairdsnet.net/up | jq .environment
```

## Authentication & Authorization

### Authentication (Devise)
- **Customized views**: Modern, styled authentication pages with Tailwind CSS
- **Root route**: `words#index` (vocabulary listing)
- **Redirects**: Custom `after_sign_in_path_for` (words_path) and `after_sign_out_path_for` (root_path)
- **Host authorization**: Configured for both GKE and minikube IP ranges in production environment

### Authorization (Pundit)
- **Role-based access control**: Superusers vs regular users
- **Policies**: ApplicationPolicy, DeckPolicy, WordPolicy, GlossPolicy
- **Superuser privileges**: Full CRUD access to all resources
- **Regular user privileges**: Can view all resources, can manage own decks
- **Read-only for non-owners**: Words and Glosses are read-only for regular users

## Recent Updates

### Audio Support Infrastructure (Phase 1 - November 2025)
- **Active Storage Setup**: Configured Rails Active Storage for audio file management
  - Installed Active Storage migrations (3 tables: blobs, attachments, variant_records)
  - Added `google-cloud-storage` gem (~> 1.47) for GCS integration
  - Configured `config/storage.yml` with separate dev/prod GCS buckets
  - Production environment now uses `:google_prod` storage service
  - Development uses `:local` storage, test uses `:test` storage
- **Google Cloud Storage Buckets**: Created two GCS buckets for audio files
  - `learning-hebrew-audio-dev` (development/staging environment)
  - `learning-hebrew-audio-prod` (production environment)
  - Both buckets in `us-central1` region with uniform bucket-level access
- **Service Account & Permissions**: Created dedicated service account for storage access
  - Service account: `audio-storage-sa@learning-hebrew-1758491674.iam.gserviceaccount.com`
  - Granted `roles/storage.objectAdmin` to both dev and prod buckets
  - Generated credentials key and stored in Google Secret Manager
  - GitHub Actions service account has `secretmanager.secretAccessor` role for CI/CD
  - Credentials file (`config/gcs_key.json`) added to `.gitignore` for security
- **Testing & Validation**:
  - All existing tests pass (338 examples, 0 failures)
  - Successfully tested blob creation/deletion in Rails console
  - Verified migrations run cleanly in both development and test environments
  - Rubocop passes with no offenses

**Technical Details:**
- Active Storage uses polymorphic attachments for flexible file association
- GCS credentials mounted via Secret Manager (not checked into git)
- Production will serve audio files directly from GCS (not through Rails)
- Local development uses filesystem storage for faster iteration

### Audio Identifiers & Word Model Integration (Phase 2 - November 2025)
- **Audio Identifier System**: Implemented cryptographic hash-based audio file identification
  - Added `audio_identifier` column to words table (string, indexed, non-unique)
  - Hash algorithm: SHA-256 of Unicode-normalized Hebrew text (first 12 characters)
  - Strips cantillation marks (U+0591-U+05AF) but preserves vowel points
  - Multiple words can share same identifier (e.g., words differing only in cantillation)
  - Auto-generated via `before_create` callback on Word model
  - Backfilled all 618 existing words with identifiers during migration
- **Word Model Audio Support**: Added audio attachment capability to Word model
  - `has_one_attached :audio_file` association via Active Storage
  - Helper methods: `audio_attached?` and `audio_url`
  - Validations: MP3 content type only, max 5MB file size
  - Audio identifier generation: `Word.hash_hebrew_text(hebrew_text)` class method
- **Testing**: Comprehensive test coverage for audio features
  - Hash generation: consistency, format validation, Unicode normalization
  - Audio identifier: auto-generation, cantillation handling, shared identifiers
  - Audio attachment: file upload, URL generation, validations (content type, size)
  - All tests pass (352 examples, 0 failures)
- **Key Insight**: Words with identical pronunciation (differing only in cantillation) share audio files
  - Example: וָאֹמַר and וָאֹמַ֫ר both have identifier `0aa1193c45d4`
  - Efficient storage: one audio file serves multiple word variants
  - Index is non-unique to support this design

**Technical Implementation:**
- Migration 20251103025102: adds column, index, and backfills existing data
- Hash algorithm location: `app/models/word.rb:124-142`
- Validation logic: `app/models/word.rb:275-287`
- Test coverage: `spec/models/word_spec.rb:451-580` (29 new tests)
- Sample audio fixture: `spec/fixtures/files/sample_audio.mp3`

**Next Steps (Phase 3):**
- Create reusable audio player UI component
- Add audio buttons to word show and dictionary pages
- Implement lazy loading (only fetch when user clicks play)
- Style audio controls with Tailwind CSS

### Hebrew Keyboard & Enhanced Search (Phase 7)
- **Interactive Hebrew Keyboard**: On-screen SIL layout keyboard for users without Hebrew input
  - Reusable partial at `app/views/shared/_hebrew_keyboard.html.erb`
  - Three-row layout matching physical Hebrew SIL keyboard positions
  - Sticky shift functionality with visual state indicator (white/blue toggle)
  - Shifted layout includes final forms (ף ך ץ ן ם), cantillation marks, and punctuation
  - Special buttons column: Hataf vowels (Qamats, Segol, Patach), Dagesh, Maqaf
  - CSS overlay technique displays vowel points underneath dotted circle (◌)
  - Collapsible toggle control to show/hide keyboard
  - Stimulus controller (`hebrew_keyboard_controller.js`) handles character insertion at cursor position
  - Supports Space and Backspace keys
- **Search Normalization**: Intelligent Hebrew search with diacritical stripping
  - `Word.normalize_hebrew()` method strips vowels, cantillation marks, and converts final forms
  - Dictionary search normalizes both query and database values via PostgreSQL
  - Searches ignore cantillation marks (e.g., אֶרֶץ matches אֶ֫רֶץ)
  - Searches ignore final forms (e.g., נון matches final nun ן)
  - Final form conversions: ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ
  - Unicode ranges covered: vowels (U+05B0-05BD, U+05BF-05C2, U+05C4-05C5, U+05C7), cantillation (U+0591-05AF)
- **Dictionary UX Enhancements**:
  - "Show all words" checkbox now defaults to checked (shows all forms, not just dictionary entries)
  - Filter state persists across searches and navigation via session storage
  - Search field has explicit `id="q"` for keyboard targeting
  - Fixed SBL Hebrew font filename from SBLHebrew.ttf to SBL_Hbrw.ttf
- **Part of Speech Categories**: Added "Phrase" and "Quantifier" to seeds
- **Tilt Development Improvements**:
  - Enhanced `Tiltfile` to sync `config/` and `db/` directories for live updates
  - Added `vocab/` to ignore list to prevent unnecessary rebuilds during vocabulary imports

**Technical Implementation:**
- Hebrew keyboard component uses Stimulus controller for DOM manipulation
- Search normalization implemented at both model level (`Word.normalize_hebrew`) and controller level (dictionary search)
- JSONB metadata supports new POS categories without schema changes
- Session storage preserves user preferences across page loads

### Dictionary Performance Optimization (Phase 8)
- **Problem Identified**: Dictionary controller was loading ALL words into memory before filtering and paginating
  - Caused slow performance, especially with Turbo prefetch triggering requests on hover
  - Example: With 5,000 words, every page view loaded all 5,000 records before showing 25
- **Solution Implemented**:
  - Added `is_dictionary_entry` boolean column to `words` table with index (migration 20251012222353)
  - Added `before_save :set_dictionary_entry_flag` callback to automatically maintain column
  - Updated dictionary controller to filter in SQL (`WHERE is_dictionary_entry = true`) before loading to memory
  - Updated `dictionary_entries` scope to use SQL instead of Ruby filtering
  - Migration automatically backfilled all existing words with correct values
- **Performance Impact**:
  - Before: `words.to_a` → Ruby filter → paginate (loaded all records every time)
  - After: SQL filter → `words.to_a` → paginate (only loads filtered subset)
  - Significantly improved response time, especially with growing vocabulary
- **Parameter Fixes**: Added `:page` and `:commit` to permitted parameters in dictionary controller
- **Test Updates**: Updated dictionary specs to pass `show_all: 'false'` for filtering tests (default changed to show all)
- **Files Changed**:
  - `db/migrate/20251012222353_add_is_dictionary_entry_to_words.rb` - migration with backfill
  - `app/models/word.rb` - added callback and updated scope (lines 53, 81, 229-231)
  - `app/controllers/dictionary_controller.rb` - SQL filtering and parameter fixes (lines 13, 65-67)
  - `spec/requests/dictionary_spec.rb` - updated tests for new default behavior

### Session Persistence & Development Improvements (Phase 9)
- **Active Record Session Store**: Implemented database-backed sessions to persist user sessions across app restarts
  - Added `activerecord-session_store` gem
  - Created `sessions` table migration (20251012225230) with proper indexes
  - Configured session store in `config/initializers/session_store.rb`
  - Users now stay logged in after app/pod restarts
  - Sessions stored in PostgreSQL with session_id uniqueness constraint
- **Tilt Configuration Updates**:
  - Added `*.md` to ignore list to prevent app restarts when editing documentation
  - Markdown files (CLAUDE.md, README.md, etc.) no longer trigger rebuilds
- **Test Fixes**:
  - Fixed view spec failures for `words/edit` and `words/show`
  - Added missing `@back_url` assignments in view specs
  - Test suite now passing: 301 examples, 0 failures, 10 pending
- **Schema Management**:
  - Fixed test database schema synchronization issues
  - Updated `db/schema.rb` with new columns (`is_dictionary_entry`, `sessions` table)
  - Ensured migrations run properly in both development and test environments
- **Developer Workflow**:
  - Created `/finish` slash command for end-of-feature workflow
  - Command runs tests, linting, documentation updates, and commit process
  - Added `script/finish-feature.sh` helper script for manual workflow
- **Files Changed**:
  - `Gemfile` - added activerecord-session_store gem
  - `db/migrate/20251012225230_add_sessions_table.rb` - sessions table migration
  - `config/initializers/session_store.rb` - session store configuration
  - `Tiltfile` - ignore markdown files (line 38)
  - `db/schema.rb` - updated with latest schema including sessions table
  - `spec/views/words/edit.html.tailwindcss_spec.rb` - added @back_url assignment
  - `spec/views/words/show.html.tailwindcss_spec.rb` - added @back_url assignment
  - `.claude/commands/finish.md` - new slash command for finish workflow

### Interactive Stories Feature (Phase 10)
- **Database-Backed Story System**: Stories stored in PostgreSQL with JSONB content column
  - Created `stories` table with title, slug, and JSONB content fields
  - GIN index on content column for efficient JSONB queries
  - Story model with automatic slug generation from title
  - Stories import from JSON files in `stories/` directory
  - Superuser-only import functionality via Import page
- **Three-Tier Dictionary Lookup API**: Sophisticated Hebrew word matching with nikkud preservation
  - **Tier 1**: Exact match including all nikkud (vowel points)
  - **Tier 2**: Final form normalization (ך→כ, ם→מ, ן→נ, ף→פ, ץ→צ) while preserving nikkud
  - **Tier 3**: Prefix removal (ה, ו, ב, כ, ל, מ, ש) with intelligent nikkud stripping
  - Rejects ambiguous matches (multiple words with same representation)
  - Returns word, gloss, and part of speech information
  - API endpoint: `/api/dictionary/lookup?word=<hebrew_word>`
- **Interactive Story View**: Click-to-reveal dictionary popups with Stimulus
  - Hebrew tokenizer separates words from punctuation while preserving text structure
  - Each Hebrew word wrapped in clickable span with Stimulus action
  - Popup displays Hebrew representation, English gloss, and part of speech
  - sessionStorage caching prevents duplicate API calls for same words
  - Viewport-aware positioning keeps popups fully visible on screen
  - Click word-to-word to see different definitions without closing/reopening
  - Click anywhere (or on popup) to dismiss
- **Story Display Sections**:
  - Hebrew text section with interactive words (24pt font, proper line height)
  - English translation section with verse-by-verse translations
  - Interlinear table with Hebrew, transliteration, and English side-by-side
- **User Experience**:
  - Stories accessible from navigation menu
  - Story index shows all imported stories with verse counts
  - Hover effect on Hebrew words (yellow highlight)
  - Clean, professional popup design with blue border
  - "Word not in dictionary" message for unknown words
  - Smooth interactions with proper event handling

**Technical Implementation:**
- `DictionaryLookupService` implements three-tier matching algorithm
- `StoriesHelper#tokenize_hebrew` uses regex to extract words from Hebrew text (U+0590-05FF Unicode range)
- `hebrew_word_controller.js` Stimulus controller manages popups and API calls
- Comprehensive test suite with 17 examples covering all matching scenarios
- Proper click event management prevents conflicts between popups and word clicks
- `adjustPopupPosition()` method ensures popups stay within viewport boundaries

**Files Changed:**
- `db/migrate/20251026204115_create_stories.rb` - Created stories table
- `app/models/story.rb` - Story model with slug generation
- `app/controllers/stories_controller.rb` - Database-backed story display
- `app/controllers/api/dictionary_controller.rb` - API endpoint for word lookups
- `app/services/dictionary_lookup_service.rb` - Three-tier matching algorithm
- `app/helpers/stories_helper.rb` - Hebrew tokenizer
- `app/javascript/controllers/hebrew_word_controller.js` - Interactive popup controller
- `app/views/stories/index.html.erb` - Story listing page
- `app/views/stories/show.html.erb` - Interactive story display with CSS
- `app/views/import/new.html.erb` - Story import section
- `app/controllers/import_controller.rb` - Story import action
- `app/policies/import_policy.rb` - Authorization for story imports
- `config/routes.rb` - API namespace and story import route
- `spec/services/dictionary_lookup_service_spec.rb` - Comprehensive test suite (17 examples)

### UI/UX Improvements (Phase 6)
- **Responsive Navigation**: Modern header with logo, active page highlighting, and user info display
- **Superuser Badge**: Visual indicator in navigation for superuser accounts
- **Styled Authentication**: Professional sign-in page with centered design and Tailwind styling
- **Flash Messages**: Styled notice/alert messages with color-coded backgrounds
- **Navigation Tests**: Comprehensive integration tests for authentication flows and navigation
- **Improved UX**: Consistent design language across all pages

### Authorization System (Phase 4)
- **Pundit Integration**: Complete authorization framework for role-based access control
- **Policy Coverage**: Comprehensive policies for all resources (Decks, Words, Glosses)
- **Superuser Access**: Full administrative capabilities for superuser accounts
- **User Restrictions**: Regular users can manage own decks, read-only access to words/glosses
- **Authorization Tests**: Full policy test coverage with 197 passing examples

### Enhanced Form UI (Phase 5)
- **Word Forms**: Deck selection via checkboxes instead of raw ID inputs
- **Gloss Forms**: Word selection via dropdown instead of raw ID inputs
- **Form Integration Tests**: Comprehensive testing of form interactions
- **Database Security**: Removed hardcoded DATABASE_URL, using individual environment variables
- **Deployment Fixes**: Fixed database seeds and authentication in Kubernetes

### Database Schema Transformation (Phase 1-3)
- **Schema Migration**: Transformed from hierarchical to many-to-many relationships
- **New DeckWord Model**: Join table with unique constraints and proper validations
- **Model Updates**: Updated all associations for Deck, Word, User models
- **Superuser Implementation**: Added superuser flag with environment-aware seeds functionality
- **Test Suite Fixes**: Resolved 32 test failures, achieved 111 passing examples with 0 failures
- **Fixture Management**: Updated all test fixtures for new many-to-many relationships
- **View Template Updates**: Modified templates to use new associations
- **Database Seeds**: Environment-aware superuser creation (development vs production passwords)

**Technical Details:**
- Created `deck_words` join table with `[deck_id, word_id]` unique index
- Removed `deck_id` foreign key from `words` table
- Added `superuser` boolean column to `users` table (default: false)
- Updated controller parameter handling for new associations
- Implemented proper `superuser?` method with nil-safe boolean conversion

### Tilt Integration for Fast Development
- **Installed Tilt v0.35.1**: Fast Kubernetes development workflow with live updates
- **Created development Docker image**: `Dockerfile.dev` optimized for development with proper user permissions
- **Implemented live code syncing**: Changes to Ruby files, views, and assets sync without rebuilds
- **Added manual database reset**: `db-reset` resource in Tilt UI for development database management
- **Fixed permission issues**: Container runs as `rails` user with proper write access for live updates
- **Tilt commands**:
  - `script/tilt-start.sh` - Start Tilt with minikube environment setup
  - `script/tilt-down.sh` - Properly stop Tilt services
  - `script/tilt.sh` - Tilt starter with environment checks
- **Live update triggers**:
  - Code changes (`app/`, `lib/`, `spec/`) sync instantly
  - Gemfile changes trigger `bundle install`
  - Asset changes trigger recompilation
  - Critical config changes trigger full rebuilds
- **Manual triggers**: Database reset available in Tilt UI (manual trigger only)

### GitHub Actions CI/CD Improvements
- **Enhanced deployment debugging**: Added comprehensive logging and error handling to GitHub Actions workflow
- **Fixed service account permissions**: GitHub Actions service account now has proper Secret Manager access
- **Added deployment timeouts**: Prevents infinite hangs during deployment rollouts
- **Improved secret management**: Better error handling when retrieving secrets from Google Secret Manager

## Previous Updates

### Security Enhancements
- **Google Secret Manager integration**: All production secrets now stored securely
- **Strong password generation**: Database and encryption keys use cryptographically secure values
- **Git security**: Removed plain-text secrets from version control
- **Automated secret injection**: CI/CD pipeline pulls secrets from Google Secret Manager

### Developer Experience
- **Bootstrap script**: `script/bootstrap.sh` for automated minikube setup from scratch
- **Environment switching scripts**: `script/dev.sh` and `script/prod.sh` for easy context switching
- **Automatic port forwarding**: Development script auto-starts localhost access
- **Pre-push Git hooks**: Rubocop and Brakeman run automatically before push to prevent CI failures
- **Deployment diagnostics**: Enhanced `/up` endpoint shows Git SHA, build info, and system status
- **Test environment isolation**: `script/test.sh` runs tests in proper test environment with separate database
- **Database configuration**: Smart host detection for local vs containerized environments using environment variables

### Infrastructure Improvements
- **Dual environment support**: Minikube (development) vs GKE (production) with proper separation
- **Build information tracking**: Git SHA, build numbers, and deployment timestamps in production
- **Local development optimization**: Faster iteration with automatic Docker builds and port forwarding
- **Monitoring readiness**: Health endpoints provide detailed deployment and system information

### Code Changes
- Set root route to words index page
- Added logout functionality with custom redirect
- Updated host authorization for Kubernetes environments
- Enhanced health controller with comprehensive system diagnostics