# Lexeme and Word Forms Project

## Overview

Implement a flexible lexeme/word-form system to handle Hebrew vocabulary variants (conjugations, pluralizations, spelling variants) while maintaining clean dictionary listings.

**Current Problem:**
- Hebrew words have many surface forms (conjugations, plurals, construct states, etc.)
- Each form needs its own audio, potentially its own glosses
- Dictionary should show only base forms (lexemes), but detail views should show all variants
- Need flexibility to add new form types without schema changes

**Solution:**
Single table with self-referential design where "forms" point back to their parent "lexeme" with flexible metadata stored in JSONB.

**Simplified Design:**
- **No `form_type` enum** - relationship determined by `lexeme_id` (null = standalone, present = form of another word)
- **Dictionary display inferred** - `is_dictionary_entry?` method checks POS + metadata (e.g., verbs: only 3MS, nouns: only singular)
- **All metadata in JSONB** - includes `pos_type`, grammatical fields, and import data
- **Optional linking** - import can provide `lexeme_of_hint` to link forms, or link later

## Can This Approach Handle the Vocabulary Schemas?

**YES! ✅** The JSONB metadata approach is perfectly suited for the analyzed vocabulary data.

**How it works:**

1. **Main database columns** (minimal structure):
   - `representation` - The Hebrew word with nikkud
   - `part_of_speech_category_id` - Links to POS category (Noun, Verb, Adjective, etc.)
   - `lexeme_id` - Points to parent word if this is a form (NULL if standalone)
   - `form_metadata` - JSONB column containing ALL grammatical information

2. **Everything else in `form_metadata` JSONB:**
   - Import fields: `pos_type`, `lesson_introduced`, `function`
   - Grammatical fields: `gender`, `number`, `status`, `aspect`, `conjugation`, etc.
   - Verb fields: `root` (optional), `binyan`, `weakness`
   - No schema changes needed to add new fields
   - Fully queryable: `Word.where("form_metadata->>'aspect' = ?", 'perfective')`

3. **Key Design Insight:** Different binyans = different standalone words
   - למד (Qal) "to learn" = Standalone word with conjugations as forms
   - למד (Piel) "to teach" = Different standalone word with its own conjugations
   - Optional `root` field (stored in metadata) can group related words, but not a core feature

**Result:** Complete linguistic precision with zero schema rigidity.

## Goals

1. ✅ Support dictionary entries (lexemes) and all their variants in one table
2. ✅ Ability to distinguish between dictionary entries and variants that will be displayed in Word#show
3. ✅ Flexible metadata: add new form types without migrations
4. ✅ Maintain existing functionality (glosses, audio URLs, search)
5. ✅ Enable rich word detail pages showing all forms
6. ✅ Support linguistic queries (e.g., "all Qal Perfect 3ms forms")
7. ✅ Handle complete Hebrew grammatical complexity (nouns, verbs, adjectives, participles, etc.)

## Database Schema Changes

### New Columns for `words` Table

```ruby
# Migration: AddLexemeSystemToWords
class AddLexemeSystemToWords < ActiveRecord::Migration[8.0]
  def change
    # Self-referential relationship - forms point to their lexeme
    add_reference :words, :lexeme, foreign_key: { to_table: :words }, null: true
    add_index :words, :lexeme_id

    # Flexible metadata (PostgreSQL JSONB)
    # Stores ALL grammatical information (number, gender, status, aspect, conjugation, etc.)
    # Also stores import fields: pos_type, lesson_introduced, function
    add_column :words, :form_metadata, :jsonb, default: {}, null: false
    add_index :words, :form_metadata, using: :gin
  end
end
```

**Design Notes:**
- No `form_type` enum needed - the relationship is determined by `lexeme_id`
- `lexeme_id` is NULL → dictionary entry (standalone word)
- `lexeme_id` is present → form of another word (the metadata tells us what kind)
- All grammatical information goes in `form_metadata` JSONB

### Form Metadata Structure (JSONB)

The `form_metadata` column stores all grammatical information plus import-specific fields.

**Common Import Fields (all words):**
```json
{
  "pos_type": "Lexical Category",  // "Lexical Category", "Functional Category", "Other/Base"
  "lesson_introduced": 1,          // Lesson number
  "function": "a man"              // Functional description
}
```

**Verb Fields:**
```json
{
  "root": "למד",                   // 3-consonant root
  "binyan": "qal",                 // qal, piel, hiphil, etc.
  "aspect": "perfective",          // perfective, imperfective, imperative, etc.
  "conjugation": "3MS",            // Combined person+gender+number
  "person": "3",                   // 1, 2, 3
  "gender": "masculine",           // masculine, feminine, common
  "number": "singular",            // singular, plural
  "weakness": "1-Nun"              // Optional: weakness type
}
```

**Noun Fields:**
```json
{
  "gender": "masculine",           // masculine, feminine
  "number": "singular",            // singular, plural, dual
  "status": "absolute",            // absolute, construct, determined
  "specific_type": "irregular plural"  // Optional: collective, epicene, etc.
}
```

**Adjective Fields:**
```json
{
  "gender": "masculine",                   // masculine, feminine
  "number": "singular",                    // singular, plural
  "definiteness_agreement": "required",    // Optional
  "category": "descriptive"                // descriptive, cardinal number, ordinal number
}
```

**Pronoun Fields:**
```json
{
  "sub_type": "Demonstrative",     // Demonstrative, Personal, Interrogative, etc.
  "gender": "masculine",           // masculine, feminine, common
  "number": "singular",            // singular, plural
  "person": "null"                 // 1st, 2nd, 3rd, or null
}
```

## Vocabulary Schema Analysis

Based on analysis of the vocabulary to be imported, the following POS categories and their metadata requirements have been identified.

**Key Point:** Only `part_of_speech_category` is stored as a database column. ALL grammatical fields are stored in `form_metadata` JSONB.

### 1. Noun (שֵׁם עֶ֫צֶם / Proper Noun)

**Database column:**
- `part_of_speech_category`: "Noun" or "Proper Noun"

**Metadata fields (in form_metadata):**
- `gender`: "masculine", "feminine" (stored as string in JSONB)
- `number`: "singular", "plural", "dual", "form only plural" (e.g., פָּנִים, שָׁמַ֫יִם)
- `status`: "absolute" (שֵׁם נִפְרָד), "construct" (שֵׁם נִסְמָךְ)
- `specific_type`: "collective", "epicene", "uncountable", "irregular plural"
- `function`: Core translation/meaning

**Dictionary entry rule:** Only singular nouns (`number == 'singular'` and `lexeme_id == nil`)

**Example words:**
- בֵּן (singular absolute) - Dictionary entry, `lexeme_id: nil`
- בָּנִים (plural absolute) - Could link to בֵּן via `lexeme_id`, or standalone
- בְּנֵי (construct plural) - Could link to בֵּן via `lexeme_id`, or standalone

### 2. Verb (פּ֫וֹעַל)

**Key Design Decision:** Different binyans of the same root are **separate standalone words**
- למד (Qal 3MS) "to learn" → Standalone word with other conjugations as forms
- למד (Piel 3MS) "to teach" → Different standalone word with its own conjugations

**Database column:**
- `part_of_speech_category`: "Verb"

**Metadata fields (in form_metadata):**
- `root`: The 3-consonant base (e.g., "למד", "הלך") - optional, for grouping related words
- `binyan`: "qal", "niphal", "piel", "pual", "hiphil", "hophal", "hitpael"
- `aspect`: "perfective" (קָטַל), "imperfective" (יִקְטֹל), "imperative", "jussive", "vayyiqtol", "veqatal"
- `conjugation`: "3MS", "1CS", etc. (person + gender + number combined)
- `person`: "1", "2", "3"
- `gender`: "masculine", "feminine", "common"
- `number`: "singular", "plural"
- `weakness`: "1-Nun", "3-He", "2-Vav (Hollow)" (optional)

**Dictionary entry rule:** Only 3MS verbs (`conjugation == '3MS'` and `lexeme_id == nil`)

**Example words:**
```ruby
# Dictionary entry: למד (Qal 3MS) "to learn"
qal_3ms = Word.create!(
  representation: "לָמַד",
  part_of_speech_category: verb_category,
  lexeme_id: nil,  # Standalone word
  form_metadata: {
    root: "למד",
    binyan: "qal",
    aspect: "perfective",
    conjugation: "3MS",
    person: "3",
    gender: "masculine",
    number: "singular"
  }
)

# Form: לָמַדְתִּי "I learned" (Qal Perfect 1CS)
Word.create!(
  representation: "לָמַדְתִּי",
  part_of_speech_category: verb_category,
  lexeme_id: qal_3ms.id,  # Points to parent
  form_metadata: {
    root: "למד",
    binyan: "qal",
    aspect: "perfective",
    conjugation: "1CS",
    person: "1",
    gender: "common",
    number: "singular"
  }
)
```

### 3. Adjective (שֵׁם תֹּ֫אַר)

**Database column:**
- `part_of_speech_category`: "Adjective"

**Metadata fields (in form_metadata):**
- `gender`: "masculine", "feminine" (for agreement)
- `number`: "singular", "plural" (for agreement)
- `definiteness_agreement`: "required"
- `category`: "descriptive", "cardinal number", "ordinal number"
- `function`: Core translation

**Dictionary entry rule:** Only masculine singular (`gender == 'masculine'` and `number == 'singular'` and `lexeme_id == nil`)

**Example words:**
- גָּדוֹל (masc singular) - Dictionary entry
- גְּדוֹלָה (fem singular) - Could link to גָּדוֹל via `lexeme_id`, or standalone
- גְּדֹלִים (masc plural) - Could link to גָּדוֹל via `lexeme_id`, or standalone
- גְּדֹלוֹת (fem plural) - Could link to גָּדוֹל via `lexeme_id`, or standalone

### 4. Participle (בֵּינוֹנִי)

**Database column:**
- `part_of_speech_category`: "Participle"

**Metadata fields (in form_metadata):**
- `verbal_root`: Link to base verb (optional)
- `aspect`: "active", "passive"
- `gender`: "masculine", "feminine"
- `number`: "singular", "plural"
- `function`: Role and translation

**Dictionary entry rule:** Only masculine singular active (`gender == 'masculine'` and `number == 'singular'` and `aspect == 'active'` and `lexeme_id == nil`)

**Example words:**
- יֹשֵׁב (active, masc singular) - Dictionary entry
- כָּתוּב (passive, masc singular) - Dictionary entry (different aspect)

### 5. Functional/Relational Words (Prepositions, Pronouns, Particles)

**Database column:**
- `part_of_speech_category`: "Preposition", "Pronoun", "Particle", "Article", "Conjunction", etc.

**Metadata fields (in form_metadata):**
- `grammatical_role`: "inseparable prefix", "object marker", "demonstrative", "relative"
- `person`: "1st", "2nd", "3rd" (for pronouns)
- `gender`: "masculine", "feminine", "common"
- `number`: "singular", "plural"
- `sub_type`: "Demonstrative", "Personal", "Interrogative", etc. (for pronouns)
- `status`: "suffixed" (e.g., לִי), "construct" (e.g., לִפְנֵי)
- `function`: Grammatical role (e.g., "the", "direct object marker", "if", "with")

**Dictionary entry rule:** All functional words are dictionary entries (each is distinct)

**Example words:**
- ה (definite article) - Dictionary entry
- אֶת־ (object marker) - Dictionary entry
- אֲנִי (1st person pronoun) - Dictionary entry
- זֶה (this, masc demonstrative) - Dictionary entry
- זֹאת (this, fem demonstrative) - Dictionary entry (different word, not a form)

### 6. Alphabet/Consonant

**Database column:**
- `part_of_speech_category`: "Consonant"

**Metadata fields (in form_metadata):**
- `name`: Hebrew letter name (e.g., "alef", "bet")
- `transliteration`: Romanization
- `status`: "sofit" (final form), "begadkefat", "guttural"
- `function`: "vowel indicator", "guttural"

**Dictionary entry rule:** All consonants are dictionary entries

**Example words:**
- א (alef) - Dictionary entry
- כ (kaf) - Dictionary entry
- ך (final kaf) - Could link to כ via `lexeme_id`, or standalone

### JSONB Metadata Flexibility

The JSONB `form_metadata` column can accommodate ALL fields from the schemas:
- Any field can be added without schema changes
- Allows for linguistic precision (weakness types, specific grammatical roles, etc.)
- Supports querying: `Word.where("form_metadata->>'aspect' = ?", 'perfective')`
- Enables form filtering: "Show me all Qal Perfect 3MS forms"
- GIN index on form_metadata provides fast queries

### Binyan Strategy (Optional Root Grouping)

For verbs with multiple binyans:
1. **Each binyan** is a separate standalone word:
   - למד (Qal) + "to learn" = Word 1 (with `conjugation: '3MS'` in metadata)
   - למד (Piel) + "to teach" = Word 2 (with `conjugation: '3MS'` in metadata)
2. **Conjugations** can be linked as forms of each binyan word via `lexeme_id`
3. **Optional `root` field** (stored in form_metadata) allows grouping: `Word.where("form_metadata->>'root' = ?", 'למד')`
   - Root grouping is not a core feature of this app
   - Root can be added during import if present in source data

This approach allows flexibility without requiring roots for basic functionality.

## Model Changes

### Word Model

```ruby
class Word < ApplicationRecord
  # Self-referential association
  belongs_to :lexeme, class_name: 'Word', optional: true
  has_many :forms, class_name: 'Word', foreign_key: :lexeme_id, dependent: :nullify

  # Existing associations
  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy
  belongs_to :part_of_speech_category, optional: true

  # Note: gender and verb_form associations can be removed in new design
  # All grammatical data now stored in form_metadata JSONB

  # JSONB store accessors for common metadata fields
  store_accessor :form_metadata,
    # Import fields
    :pos_type,            # "Lexical Category", "Functional Category", "Other/Base"
    :lesson_introduced,   # Lesson number
    :function,            # Functional description

    # Verb fields
    :root,                # 3-consonant root (e.g., "למד")
    :binyan,              # qal, niphal, piel, pual, hiphil, hophal, hitpael
    :aspect,              # perfective, imperfective, imperative, jussive, etc.
    :conjugation,         # 3MS, 1CS, etc. (person+gender+number combined)
    :person,              # 1, 2, 3
    :weakness,            # 1-Nun, 3-He, 2-Vav (Hollow), etc.

    # Noun/Adjective fields
    :number,              # singular, plural, dual, form only plural
    :status,              # absolute, construct, determined
    :specific_type,       # collective, epicene, uncountable, irregular plural
    :definiteness_agreement, # For adjectives

    # Participle fields
    :verbal_root,         # Link to base verb

    # Pronoun fields
    :sub_type,            # Demonstrative, Personal, Interrogative, etc.

    # Functional word fields
    :grammatical_role,    # inseparable prefix, object marker, etc.

    # General fields
    :gender,              # masculine, feminine, common (used across nouns, adjectives, pronouns, etc.)
    :category,            # descriptive, cardinal number, ordinal number, etc.
    :variant_type,        # plene, defective, modern, ancient
    :notes,               # Additional notes
    :name,                # Letter name (for consonants)
    :transliteration      # Romanization

  # Validations
  validates :representation, presence: true
  validates :form_metadata, presence: true

  # Scopes
  scope :dictionary_entries, -> {
    where(lexeme_id: nil).select { |w| w.is_dictionary_entry? }
  }
  scope :for_dictionary, -> {
    includes(:glosses, :forms, :part_of_speech_category, :gender)
      .where(lexeme_id: nil)
      .select { |w| w.is_dictionary_entry? }
  }
  scope :word_forms, -> { where.not(lexeme_id: nil) }

  # Helper methods
  def is_dictionary_entry?
    # Forms are never dictionary entries
    return false if lexeme_id.present?

    # Determine based on POS category and metadata
    case part_of_speech_category&.name
    when "Verb"
      # Only 3MS (3rd person masculine singular) is dictionary entry
      form_metadata['conjugation'] == '3MS'

    when "Noun", "Proper Noun"
      # Only singular forms are dictionary entries
      form_metadata['number'] == 'singular'

    when "Adjective"
      # Only masculine singular is dictionary entry
      form_metadata['gender'] == 'masculine' && form_metadata['number'] == 'singular'

    when "Participle"
      # Only masculine singular active is dictionary entry
      form_metadata['gender'] == 'masculine' &&
        form_metadata['number'] == 'singular' &&
        form_metadata['aspect'] == 'active'

    when "Pronoun", "Interrogative Pronoun"
      # All pronouns are dictionary entries (each is distinct)
      true

    when "Preposition", "Conjunction", "Article", "Particle", "Adverb/Particle"
      # All functional words are dictionary entries
      true

    when "Consonant"
      # All consonants are dictionary entries
      true

    else
      # Default: show in dictionary if no lexeme_id
      true
    end
  end

  def parent_word
    lexeme_id.present? ? lexeme : self
  end

  def form_description
    return "Dictionary entry" if is_dictionary_entry?

    # Describe the form based on metadata
    if form_metadata['conjugation'].present?
      # Verb conjugation
      parts = [
        form_metadata['binyan'],
        form_metadata['aspect'],
        form_metadata['conjugation']
      ].compact
      parts.join(' ')
    elsif form_metadata['number'] == 'plural'
      # Plural noun/adjective
      "plural #{form_metadata['status'] || 'form'}"
    elsif form_metadata['status'] == 'construct'
      # Construct state
      "construct #{form_metadata['number'] || 'form'}"
    else
      # Generic description
      "variant"
    end
  end

  def full_display_name
    parts = [representation]
    parts << "(#{form_description})" unless is_dictionary_entry?
    parts.join(' ')
  end
end
```

## Migration Strategy

### Phase 1: Add Schema

1. Run migration to add columns (lexeme_id, form_type, form_metadata)
2. All columns have appropriate defaults (form_type: 0 for lexeme)
3. Add indexes and constraints

### Phase 2: Update Application Code

Update code to use new features:
- `Word.dictionary_entries` for dictionary listings
- `Word.for_dictionary` with eager loading
- Form creation through UI or import

## Controller Changes

### DictionaryController

```ruby
class DictionaryController < ApplicationController
  def index
    # Only show lexemes in dictionary
    all_words = Word.dictionary_entries.includes(:glosses, :part_of_speech_category, :gender)
                   .alphabetically
    @words = Kaminari.paginate_array(all_words).page(params[:page]).per(25)
  end
end
```

### WordsController

```ruby
class WordsController < ApplicationController
  def show
    @word = Word.find(params[:id])

    # If this is a form, redirect to its lexeme's show page with anchor
    if @word.form? && @word.lexeme.present?
      redirect_to word_path(@word.lexeme, anchor: "form-#{@word.id}")
      return
    end

    # Load all forms for display
    @conjugations = @word.forms.conjugations.order(:binyan, :tense, :person)
    @pluralizations = @word.forms.pluralizations.order(:number_form)
    @variants = @word.forms.spelling_variant

    authorize @word
  end

  def new
    @word = Word.new
    @lexemes = Word.dictionary_entries.order(:representation)  # For form creation
    load_form_data
    authorize @word
  end

  private

  def word_params
    params.expect(word: [
      :representation,
      :part_of_speech_category_id,
      :gender_id,
      :verb_form_id,
      :mnemonic,
      :pronunciation_url,
      :picture_url,
      :form_type,
      :lexeme_id,
      :binyan,
      :tense,
      :person,
      :gender_form,
      :number_form,
      :state,
      :variant_type,
      :notes,
      deck_ids: []
    ])
  end
end
```

## View Changes

### Dictionary Index (No Change Needed)

Already shows `word.pos_display` - will work for lexemes.

### Word Show Page (Enhanced)

```erb
<!-- app/views/words/show.html.erb -->
<div class="w-full">
  <h1 class="text-4xl font-hebrew mb-4"><%= @word.representation %></h1>

  <% if @word.pos_display.present? %>
    <p class="text-lg text-gray-600 mb-2">(<%= @word.pos_display %>)</p>
  <% end %>

  <!-- Glosses -->
  <div class="mb-6">
    <h2 class="text-2xl font-bold mb-2">Definitions</h2>
    <% if @word.glosses.any? %>
      <p><%= @word.formatted_glosses %></p>
    <% else %>
      <p class="text-gray-500 italic">No definitions yet</p>
    <% end %>
  </div>

  <!-- Conjugations -->
  <% if @conjugations.any? %>
    <div class="mb-6">
      <h2 class="text-2xl font-bold mb-2">Conjugations</h2>
      <table class="min-w-full">
        <thead>
          <tr>
            <th>Form</th>
            <th>Binyan</th>
            <th>Tense</th>
            <th>Person</th>
            <th>Audio</th>
          </tr>
        </thead>
        <tbody>
          <% @conjugations.each do |form| %>
            <tr id="form-<%= form.id %>">
              <td class="font-hebrew text-xl"><%= form.representation %></td>
              <td><%= form.binyan %></td>
              <td><%= form.tense %></td>
              <td><%= form.person %><%= form.gender_form %><%= form.number_form %></td>
              <td>
                <% if form.pronunciation_url.present? %>
                  <audio controls src="<%= form.pronunciation_url %>"></audio>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>

  <!-- Pluralizations -->
  <% if @pluralizations.any? %>
    <div class="mb-6">
      <h2 class="text-2xl font-bold mb-2">Plural Forms</h2>
      <% @pluralizations.each do |form| %>
        <div id="form-<%= form.id %>" class="mb-2">
          <span class="font-hebrew text-xl"><%= form.representation %></span>
          <span class="text-gray-600">(<%= form.form_description %>)</span>
          <% if form.pronunciation_url.present? %>
            <audio controls src="<%= form.pronunciation_url %>" class="ml-2"></audio>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <!-- Spelling Variants -->
  <% if @variants.any? %>
    <div class="mb-6">
      <h2 class="text-2xl font-bold mb-2">Spelling Variants</h2>
      <% @variants.each do |form| %>
        <div class="mb-2">
          <span class="font-hebrew text-xl"><%= form.representation %></span>
          <% if form.notes.present? %>
            <span class="text-gray-600 text-sm">- <%= form.notes %></span>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

### Word Form (Enhanced)

Add fields for creating word forms:

```erb
<!-- app/views/words/_form.html.erb -->

<!-- Form Type Selection -->
<div class="my-5">
  <%= form.label :form_type, "Word Type" %>
  <%= form.select :form_type,
    Word.form_types.map { |k, v| [k.humanize, k] },
    { selected: word.form_type || 'lexeme' },
    { class: "block shadow-sm rounded-md border border-gray-400 px-3 py-2 mt-2 w-full" } %>
</div>

<!-- Lexeme Selection (only show for forms, not lexemes) -->
<div class="my-5" data-form-target="lexemeSelect">
  <%= form.label :lexeme_id, "Parent Lexeme" %>
  <%= form.collection_select :lexeme_id,
    @lexemes || Word.dictionary_entries.order(:representation),
    :id, :representation,
    { include_blank: "(select parent word)", selected: word.lexeme_id },
    { class: "block shadow-sm rounded-md border border-gray-400 px-3 py-2 mt-2 w-full font-hebrew" } %>
</div>

<!-- Metadata Fields (conditional on form_type) -->
<div class="border-t pt-4 my-5" data-form-target="conjugationFields">
  <h3 class="font-bold mb-2">Conjugation Details</h3>

  <div class="grid grid-cols-2 gap-4">
    <div>
      <%= form.label :binyan %>
      <%= form.select :binyan,
        ['qal', 'niphal', 'piel', 'pual', 'hiphil', 'hophal', 'hitpael'],
        { include_blank: true },
        { class: "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full" } %>
    </div>

    <div>
      <%= form.label :tense %>
      <%= form.select :tense,
        ['perfect', 'imperfect', 'imperative', 'infinitive', 'participle'],
        { include_blank: true },
        { class: "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full" } %>
    </div>

    <div>
      <%= form.label :person %>
      <%= form.select :person, ['1', '2', '3'],
        { include_blank: true },
        { class: "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full" } %>
    </div>

    <div>
      <%= form.label :gender_form, "Gender" %>
      <%= form.select :gender_form, ['m', 'f', 'c'],
        { include_blank: true },
        { class: "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full" } %>
    </div>
  </div>
</div>

<!-- Add similar sections for pluralization, construct state metadata -->
```

## Import Strategy

All vocabulary data (both lexemes and forms) will be imported from a JSON file. See `import_format_schema.md` for the complete JSON schema specification.

### ImportController Enhancement

```ruby
def import_words(json_data)
  ActiveRecord::Base.transaction do
    json_data['lexemes'].each do |lexeme_data|
      # Create lexeme
      lexeme = Word.create!(
        representation: lexeme_data['representation'],
        form_type: :lexeme,
        part_of_speech_category: find_or_create_pos(lexeme_data['pos']),
        gender: find_gender(lexeme_data['gender']),
        form_metadata: lexeme_data['metadata'] || {}
      )

      # Create glosses
      lexeme_data['glosses'].each do |gloss_text|
        lexeme.glosses.create!(text: gloss_text)
      end

      # Create forms if present
      lexeme_data['forms']&.each do |form_data|
        Word.create!(
          representation: form_data['representation'],
          lexeme: lexeme,
          form_type: form_data['form_type'],
          form_metadata: form_data['metadata'],
          pronunciation_url: form_data['audio_url']
        )
      end
    end
  end
end
```

## Search & Query Patterns

### Finding Forms

```ruby
# All Qal Perfect forms
Word.conjugations.where("form_metadata->>'binyan' = ?", 'qal')
    .where("form_metadata->>'tense' = ?", 'perfect')

# All plural forms of a word
word.forms.pluralizations

# Specific conjugation
word.forms.conjugations.find_by(
  binyan: 'qal',
  tense: 'perfect',
  person: '3',
  gender_form: 'm',
  number_form: 's'
)
```

### Search Enhancements

Update global search to find both lexemes and forms, showing parent:

```ruby
# app/controllers/search_controller.rb
def search
  query = params[:q]

  @results = Word.where("representation ILIKE ?", "%#{query}%")
                 .includes(:lexeme)
                 .limit(20)

  # Group by lexeme
  @grouped_results = @results.group_by(&:parent_word)
end
```

## Testing Strategy

### Model Tests

```ruby
# spec/models/word_spec.rb
describe 'lexeme/form relationships' do
  let(:lexeme) { Word.create!(representation: 'למד', form_type: :lexeme) }

  describe 'lexeme validations' do
    it 'cannot have a lexeme_id' do
      word = Word.new(representation: 'test', form_type: :lexeme, lexeme: lexeme)
      expect(word).not_to be_valid
    end
  end

  describe 'form validations' do
    it 'must have a lexeme_id' do
      word = Word.new(representation: 'למדתי', form_type: :conjugation)
      expect(word).not_to be_valid
    end

    it 'must have metadata' do
      word = Word.new(
        representation: 'למדתי',
        form_type: :conjugation,
        lexeme: lexeme
      )
      expect(word).not_to be_valid

      word.binyan = 'qal'
      expect(word).to be_valid
    end
  end

  describe 'form associations' do
    let!(:form1) { Word.create!(
      representation: 'למדתי',
      lexeme: lexeme,
      form_type: :conjugation,
      binyan: 'qal',
      tense: 'perfect'
    )}

    it 'loads forms from lexeme' do
      expect(lexeme.forms).to include(form1)
    end

    it 'finds parent from form' do
      expect(form1.lexeme).to eq(lexeme)
    end
  end
end

describe 'scopes' do
  let!(:lexeme) { Word.create!(representation: 'למד', form_type: :lexeme) }
  let!(:form) { Word.create!(
    representation: 'למדתי',
    lexeme: lexeme,
    form_type: :conjugation,
    binyan: 'qal'
  )}

  it 'dictionary_entries returns only lexemes' do
    expect(Word.dictionary_entries).to include(lexeme)
    expect(Word.dictionary_entries).not_to include(form)
  end

  it 'conjugations returns only conjugations' do
    expect(Word.conjugations).to include(form)
    expect(Word.conjugations).not_to include(lexeme)
  end
end

describe '#form_description' do
  it 'describes conjugations' do
    word = Word.new(
      form_type: :conjugation,
      binyan: 'qal',
      tense: 'perfect',
      person: '1',
      gender_form: 'c',
      number_form: 's'
    )
    expect(word.form_description).to eq('qal perfect 1cs')
  end
end
```

### Request Tests

```ruby
# spec/requests/words_spec.rb
describe 'GET /words/:id with forms' do
  let(:lexeme) { Word.create!(representation: 'למד', form_type: :lexeme) }
  let!(:conjugation) { Word.create!(
    representation: 'למדתי',
    lexeme: lexeme,
    form_type: :conjugation,
    binyan: 'qal'
  )}

  it 'displays forms on lexeme show page' do
    get word_path(lexeme)
    expect(response.body).to include('למדתי')
    expect(response.body).to include('qal')
  end

  it 'redirects form to lexeme with anchor' do
    get word_path(conjugation)
    expect(response).to redirect_to(word_path(lexeme, anchor: "form-#{conjugation.id}"))
  end
end
```

## Implementation Checklist

### Phase 1: Database Migration ✅
**Goal:** Add new columns to support lexeme/form relationships without breaking existing functionality

- [x] **1.1** Create migration file: `db/migrate/YYYYMMDDHHMMSS_add_lexeme_system_to_words.rb`
- [x] **1.2** Add `lexeme_id` reference column (nullable, references words table)
- [x] **1.3** Add index on `lexeme_id`
- [x] **1.4** Add `form_metadata` JSONB column (default: `{}`, not null)
- [x] **1.5** Add GIN index on `form_metadata` for fast JSONB queries
- [x] **1.6** Run migration in development: `bin/rails db:migrate`
- [x] **1.7** Verify schema changes: `bin/rails db:schema:dump`
- [x] **1.8** Run existing test suite: `bundle exec rspec` (should still pass)

**Acceptance Criteria:**
- ✅ New columns exist in schema
- ✅ All existing tests pass (no breaking changes)
- ✅ Can query `Word.where("form_metadata->>'gender' = ?", 'masculine')`

---

### Phase 2: Model Associations & Accessors ✅
**Goal:** Update Word model with new associations and JSONB accessors

- [x] **2.1** Add self-referential associations to `app/models/word.rb`:
  - `belongs_to :lexeme, class_name: 'Word', optional: true`
  - `has_many :forms, class_name: 'Word', foreign_key: :lexeme_id, dependent: :nullify`
- [x] **2.2** Add `store_accessor :form_metadata` with all fields (pos_type, lesson_introduced, function, root, binyan, aspect, etc.)
- [x] **2.3** Update validations:
  - `validates :representation, presence: true`
  - Note: form_metadata validation not needed (NOT NULL with default in DB)
- [x] **2.4** Add scopes:
  - `scope :word_forms, -> { where.not(lexeme_id: nil) }`
- [x] **2.5** Run tests: `bundle exec rspec spec/models/word_spec.rb`

**Acceptance Criteria:**
- ✅ Can access metadata fields via accessors: `word.gender_meta`, `word.binyan`, etc.
- ✅ Associations work: `parent.forms` returns linked words
- ✅ Tests pass

---

### Phase 3: Dictionary Entry Logic ✅
**Goal:** Implement `is_dictionary_entry?` method with POS-specific rules

- [x] **3.1** Add `is_dictionary_entry?` method to Word model
- [x] **3.2** Implement rules for Verbs (only 3MS with `lexeme_id: nil`)
- [x] **3.3** Implement rules for Nouns (only singular with `lexeme_id: nil`)
- [x] **3.4** Implement rules for Adjectives (only masculine singular with `lexeme_id: nil`)
- [x] **3.5** Implement rules for Participles (only masculine singular active with `lexeme_id: nil`)
- [x] **3.6** Implement rules for Pronouns/Functional words (all are dictionary entries)
- [x] **3.7** Implement rules for Consonants (all are dictionary entries)
- [x] **3.8** Add `dictionary_entries` scope (filters by `is_dictionary_entry?`)
- [x] **3.9** Write model tests for `is_dictionary_entry?` logic
- [x] **3.10** Run tests: `bundle exec rspec spec/models/word_spec.rb`

**Acceptance Criteria:**
- ✅ `Word.dictionary_entries` returns only appropriate words
- ✅ 3MS verbs return true, 1CS verbs return false
- ✅ Singular nouns return true, plural nouns return false
- ✅ Tests cover all POS categories

---

### Phase 4: Helper Methods ✅
**Goal:** Add helper methods for word display and description

- [x] **4.1** Add `parent_word` method (returns self if standalone, else returns lexeme)
- [x] **4.2** Add `form_description` method (describes grammatical features from metadata)
- [x] **4.3** Add `full_display_name` method (combines representation + form description)
- [x] **4.4** Write tests for helper methods
- [x] **4.5** Run tests: `bundle exec rspec spec/models/word_spec.rb`

**Acceptance Criteria:**
- ✅ `word.form_description` returns appropriate string (e.g., "qal perfective 1CS")
- ✅ `word.parent_word` returns correct word
- ✅ Tests pass (263 examples, 0 failures)

---

### Phase 5: Dictionary Controller Updates ✅
**Goal:** Update dictionary to show only dictionary entry words

- [x] **5.1** Update `DictionaryController#index` to use filtered query
- [x] **5.2** Filter by `is_dictionary_entry?` (may need to load all and filter in Ruby initially)
- [x] **5.3** Update eager loading to include metadata needed for filtering
- [x] **5.4** Test dictionary page manually (verify only appropriate words show)
- [x] **5.5** Write/update request specs for dictionary
- [x] **5.6** Run tests: `bundle exec rspec spec/requests/dictionary_spec.rb`

**Acceptance Criteria:**
- ✅ Dictionary page shows only 3MS verbs, singular nouns, etc.
- ✅ No plural forms or non-3MS verbs appear
- ✅ Page loads in reasonable time
- ✅ Tests pass (267 examples, 0 failures, added 4 comprehensive filtering tests)

---

### Phase 6: Word Show Page Enhancements ✅
**Goal:** Display linked words on word detail pages

- [x] **6.1** Update `WordsController#show` to load linked words via `@word.forms`
- [x] **6.2** Add redirect logic: if word has `lexeme_id`, redirect to parent with anchor
- [x] **6.3** Update `app/views/words/show.html.erb` to display linked words
- [x] **6.4** Group linked words by type (conjugations, plurals, etc.) using metadata
- [x] **6.5** Add anchors for each linked word (for redirects)
- [x] **6.6** Order linked words logically (by grammatical features)
- [x] **6.7** Test show page with standalone words (no linked words)
- [x] **6.8** Test show page with linked words
- [x] **6.9** Test redirect from linked word to parent
- [x] **6.10** Write/update request specs
- [x] **6.11** Run tests: `bundle exec rspec spec/requests/words_spec.rb`

**Acceptance Criteria:**
- ✅ Word show page displays all linked words in organized sections
- ✅ Visiting `/words/:id` where word has `lexeme_id` redirects to parent
- ✅ Tests pass (273 examples, 0 failures)

---

### Phase 7: Word Form UI ✅
**Goal:** Enable creating/editing words with metadata through UI

- [x] **7.1** Update `app/views/words/_form.html.erb` to include metadata fields
- [x] **7.2** Add lexeme selection dropdown (for linking words)
- [x] **7.3** Add conditional field visibility based on POS category
- [x] **7.4** Add fields for common metadata: gender, number, status, conjugation, etc.
- [x] **7.5** Update `WordsController` strong params to permit metadata fields
- [x] **7.6** Add Stimulus controller for dynamic field visibility (optional)
- [x] **7.7** Test creating standalone word through UI
- [x] **7.8** Test creating linked word through UI
- [x] **7.9** Test editing word metadata
- [x] **7.10** Write/update request specs
- [x] **7.11** Run tests: `bundle exec rspec spec/requests/words_spec.rb`

**Acceptance Criteria:**
- ✅ Can create words with metadata through web form
- ✅ Can link words to parent via dropdown
- ✅ Metadata saves correctly to form_metadata JSONB
- ✅ Tests pass (278 examples, 0 failures)

---

### Phase 8: Import System Updates ✅
**Goal:** Update import to handle new JSON format with metadata

- [x] **8.1** Review current `DictionaryImportParser` and `ImportController`
- [x] **8.2** Update parser to handle `pos_detail` object
- [x] **8.3** Update importer to merge `pos_detail`, `pos_type`, `lesson_introduced`, `function` into `form_metadata`
- [x] **8.4** Add support for `lexeme_of_hint` field (optional linking)
- [x] **8.5** Update `ImportController` to look up parent words by representation
- [x] **8.6** Set `lexeme_id` if parent found, leave NULL if not
- [x] **8.7** Update import tests to use new JSON format
- [x] **8.8** Test importing flat words (no lexeme_of_hint)
- [x] **8.9** Test importing linked words (with lexeme_of_hint)
- [x] **8.10** Run tests: `bundle exec rspec spec/services/dictionary_import_parser_spec.rb spec/requests/import_spec.rb`

**Acceptance Criteria:**
- ✅ Can import JSON with new format
- ✅ Metadata stored correctly in form_metadata
- ✅ lexeme_of_hint creates proper links when parent exists
- ✅ Tests pass (292 examples, 0 failures)

---

### Phase 9: Search & Query Enhancements ✅
**Goal:** Update search to handle metadata and dictionary filtering

- [x] **9.1** Update search to filter by dictionary entries by default
- [x] **9.2** Add option to search all words (not just dictionary entries)
- [x] **9.3** Add metadata-based filters (e.g., "show only verbs", "show only Qal")
- [x] **9.4** Update search results to show word metadata
- [x] **9.5** Add lesson number filtering (exact and cumulative "or less" modes)
- [x] **9.6** Test search functionality
- [x] **9.7** Write/update search specs
- [x] **9.8** Run tests: `bundle exec rspec spec/requests/dictionary_spec.rb`

**Acceptance Criteria:**
- ✅ Search shows only dictionary entries by default
- ✅ Can filter by metadata fields (POS, binyan, number)
- ✅ Can filter by lesson number (exact or cumulative "or less" mode)
- ✅ Tests pass (301 examples, 0 failures)

---

### Phase 10: Performance Optimization ✅
**Goal:** Ensure queries perform well with metadata

- [x] **10.1** Add eager loading where needed (avoid N+1 queries)
- [x] **10.2** Verify GIN index is being used for JSONB queries
- [x] **10.3** Add eager loading to Words#index (includes :decks, :glosses)
- [x] **10.4** Add eager loading to Words#show (includes :glosses, :decks)
- [x] **10.5** Verify DictionaryController already has proper eager loading
- [x] **10.6** Run tests to verify no regressions

**Acceptance Criteria:**
- ✅ GIN index exists on form_metadata column for fast JSONB queries
- ✅ Words#index eager loads :decks and :glosses to prevent N+1 queries
- ✅ Words#show eager loads :glosses and :decks for @word
- ✅ DictionaryController already includes :glosses and :part_of_speech_category
- ✅ All tests pass (301 examples, 0 failures)

---

### Phase 11: Testing & Documentation ✅
**Goal:** Ensure complete test coverage and documentation

- [x] **11.1** Write integration tests for complete workflows
- [x] **11.2** Test importing words → viewing dictionary → viewing word details
- [x] **11.3** Test creating linked words → viewing parent word
- [x] **11.4** Update CLAUDE.md with new features
- [x] **11.5** Run full test suite: `bundle exec rspec`
- [x] **11.6** Verify test coverage with comprehensive test examples

**Acceptance Criteria:**
- ✅ All tests pass (301 examples, 0 failures, 10 pending)
- ✅ Integration tests cover complete workflows (import, dictionary, word details, linked forms)
- ✅ CLAUDE.md updated with lexeme/form system documentation
- ✅ Database schema and model relationships documented
- ✅ Search & filtering features documented

---

### Phase 12: Cleanup & Polish
**Goal:** Remove deprecated code and polish UI

- [ ] **12.1** Consider removing `gender_id` and `verb_form_id` columns (if no longer needed)
- [ ] **12.2** Add CSS styling for linked word displays
- [ ] **12.3** Polish form UI for metadata input
- [ ] **12.4** Add helpful tooltips/labels for metadata fields
- [ ] **12.5** Manual testing of entire flow
- [ ] **12.6** Final commit and push

**Acceptance Criteria:**
- No unused columns in database
- UI is polished and user-friendly
- All functionality works end-to-end

## Edge Cases & Considerations

### 1. Orphan Forms
**Problem:** What if a dictionary entry word is deleted that other words link to via `lexeme_id`?
**Solution:** Set `lexeme_id` to NULL for linked words, but don't delete them
- Model association should use `dependent: :nullify` instead of `dependent: :destroy`
- Orphaned words become standalone words (can be re-linked later)
- Dictionary display may change (words that were hidden may now appear)

### 2. Words Without Audio
**Acceptable:** Not all words need audio initially
**Solution:** `pronunciation_url` is optional, can be added incrementally
- Works for both dictionary entries and forms
- Audio can be batch-uploaded later

### 3. Homonyms (Same Spelling, Different Meanings)
**Example:** בַּ֫יִת (house) and בַּ֫יִת (verse) are different words despite identical spelling
**Solution:** These are separate Word records with different glosses
- Forms point to the correct parent via `lexeme_id`
- Search may return both (show in results with their glosses)

### 4. Word-Specific Glosses
**Example:** A plural form might have a unique meaning different from the singular
**Solution:** All words can have their own glosses
- Glosses belong to Word model (not restricted to dictionary entries)
- Allows linguistic precision for forms with idiomatic meanings

### 5. JSONB Query Performance
**Concern:** Searching metadata could be slow with large datasets
**Solution:** GIN index on `form_metadata` provides fast queries
- Query example: `Word.where("form_metadata->>'conjugation' = ?", '3MS')`
- GIN indexes support all JSONB operators efficiently
**Alternative:** Add computed columns for frequently queried fields if performance issues arise

### 6. Import Order Dependencies
**Problem:** `lexeme_of_hint` might reference a word that hasn't been imported yet
**Solution:** Import handles missing parents gracefully
- If parent not found, leaves `lexeme_id` as NULL
- Words can be re-imported or manually linked later via UI
**Best Practice:** Import dictionary entries before their forms

### 7. Form Display Order
**Concern:** How to order conjugations/forms logically on word detail pages?
**Solution:** Order by standard grammatical order using metadata fields
- Verbs: binyan → aspect → person → gender → number
- Nouns: number → status
- Query: `word.forms.order(Arel.sql("form_metadata->>'aspect', form_metadata->>'conjugation'"))`

### 8. Dictionary Entry Rule Changes
**Concern:** What if we need to change `is_dictionary_entry?` logic later?
**Solution:** Rules are in model code, not data
- Can update method without migrations
- Re-run dictionary display queries to reflect new rules
- Example: Could add "also show dual nouns" rule without touching database

### 9. Duplicate Imports
**Problem:** Re-importing same JSON file creates duplicate words
**Solution:** Use `find_or_create_by(representation: ...)` in importer
- Optionally update existing words instead of creating duplicates
- Or use `find_or_initialize_by` and update metadata

### 10. Words That Are Both Dictionary Entries and Forms
**Example:** Could a verb be both a standalone word AND a form of another verb?
**Unlikely but possible:** Defective verbs that share forms
**Solution:** A word is EITHER standalone (`lexeme_id: nil`) OR a form (`lexeme_id: present`)
- Can't be both simultaneously
- If needed, create two separate Word records

## Future Enhancements

### 1. Bulk Conjugation Import
Create a dedicated importer for verb paradigms:
```ruby
# Uploads a CSV with all conjugations for a verb
conjugation_csv = "representation,binyan,aspect,person,gender,number\nלמדתי,qal,perfective,1,common,singular\n..."
ConjugationImporter.import_paradigm(parent_word, conjugation_csv)
# Creates linked words with lexeme_id pointing to parent_word
```

### 2. Conjugation Generator
Auto-generate expected conjugations from a 3MS verb:
```ruby
# Generate all expected Qal Perfect forms from base verb
parent_verb = Word.find_by(representation: "לָמַד")
ConjugationGenerator.generate_qal_perfect(parent_verb)
# Creates 14 linked words (3 persons × 2-3 genders × 2 numbers)
# Each with lexeme_id pointing to parent_verb
```

### 3. Audio Batch Upload
Link audio files to words by naming convention:
```ruby
# Upload: lamad_qal_perfect_1cs.mp3
# Automatically finds word with matching metadata and adds audio URL
AudioLinker.link_from_filename("lamad_qal_perfect_1cs.mp3")
# Matches: Word with root="למד", binyan="qal", aspect="perfective", conjugation="1CS"
```

### 4. Form Comparison View
Show conjugation tables side-by-side for related verbs

### 5. Quiz Integration
Generate quizzes from word metadata:
- "What is the Qal Perfect 1CS of למד?" (answer: לָמַדְתִּי)
- "What is the plural of בַּ֫יִת?" (answer: בָּתִּים)
- Quiz generation uses metadata queries to find correct answers

### 6. Root-Based Grouping
Enhanced UI for grouping words by shared root:
```ruby
# Find all words with same root
root_words = Word.where("form_metadata->>'root' = ?", 'למד')
# Display as word family: למד (Qal), למד (Piel), למד (Hiphil), etc.
```
- Root field already available in metadata (optional)
- Could add dedicated UI for browsing by root
- Useful for advanced learners studying word families

## Success Metrics

1. ✅ Dictionary shows only dictionary entry words (determined by `is_dictionary_entry?` method)
2. ✅ Word detail pages show all linked words organized by grammatical features
3. ✅ Can create/edit both standalone words and linked words through UI
4. ✅ All 238+ tests passing
5. ✅ No breaking changes to existing functionality
6. ✅ JSONB queries perform well (< 100ms with GIN index)
7. ✅ Easy to add new grammatical fields without migrations (just update metadata)
8. ✅ Dictionary entry rules can be updated without migrations (just update `is_dictionary_entry?` method)

## Design Decisions (Resolved)

1. **Should all words appear in global search results?**
   - ✅ **Decision:** Show only dictionary entry words in search results by default
   - Dictionary entries determined by `is_dictionary_entry?` method (checks POS + metadata)
   - Add user-selectable filters to show all words or specific forms
   - Example: Search for "למד" shows only 3MS verb, not all conjugations

2. **Should words with `lexeme_id` have their own URLs or redirect?**
   - ✅ **Decision:** Words with `lexeme_id` redirect to their parent word's show page
   - Only dictionary entries (`lexeme_id: nil` + `is_dictionary_entry? == true`) have dedicated show URLs
   - All related words displayed within parent word's show page
   - URL format: `/words/:id` where `:id` is the dictionary entry word

3. **How to handle multiple grammatical features in one word? (e.g., plural construct state)**
   - ✅ **Decision:** Store all features in single `form_metadata` JSONB
   - Example: plural construct has `number: "plural"`, `status: "construct"`, `gender: "masculine"` all in one metadata object
   - No need for nested relationships or multiple records

4. **Should `part_of_speech_category` be duplicated for linked words?**
   - ✅ **Decision:** Each word has its own `part_of_speech_category_id`
   - Usually the same as parent, but can differ if needed (e.g., participle derived from verb)
   - Not inherited/computed - stored explicitly for each word

5. **Can words belong to decks individually or only via their parent?**
   - ✅ **Decision:** ANY word can have deck associations independently
   - Allows specialized decks: "Plural Forms Practice", "Qal Perfect 3MS Drill", "Irregular Plurals", etc.
   - The existing `deck_words` join table supports this (points to words table regardless of `lexeme_id`)
   - Dictionary entry words and linked words are treated equally for deck membership

6. **How do we determine which words show in dictionary?**
   - ✅ **Decision:** Computed method `is_dictionary_entry?` based on POS + metadata + `lexeme_id`
   - NOT a database field - rules can change without migration
   - Rules per POS category:
     - Verbs: Only 3MS (`conjugation == '3MS'`)
     - Nouns: Only singular (`number == 'singular'`)
     - Adjectives: Only masculine singular
     - Pronouns/Functional words: All are dictionary entries
   - All words with `lexeme_id` present are never dictionary entries

7. **Should we use `form_type` enum to categorize words?**
   - ✅ **Decision:** NO - relationship determined solely by `lexeme_id`
   - `lexeme_id: nil` = standalone word (may or may not be dictionary entry based on metadata)
   - `lexeme_id: present` = linked to another word (never a dictionary entry)
   - Metadata fields describe WHAT the word is, `lexeme_id` describes the RELATIONSHIP

## Next Steps

1. Review and refine this document
2. Get approval on approach
3. Break into atomic implementation tasks
4. Execute phase by phase with testing at each step
