# Hebrew Vocabulary Import Format Schema

## Overview

This document defines the JSON schema for importing Hebrew vocabulary data into the learning application. The format supports importing all Hebrew words (both dictionary entries and linked words) with complete grammatical metadata.

**Key Design Principles:**
- **Flat structure**: Each JSON entry represents a single word (not nested)
- **Dictionary display inferred**: Determined by `is_dictionary_entry?` method checking POS + metadata (not a database flag)
- **Optional linking**: Words can link to parent words via `lexeme_of_hint` field
- **Metadata in JSONB**: All grammatical info stored in `form_metadata` JSONB column for maximum flexibility
- **No form_type enum**: Relationship determined by `lexeme_id` (NULL = standalone, present = linked to parent)

## Dictionary Entry Rules

After import, which words appear in the dictionary is determined by the `is_dictionary_entry?` method:

| POS Category | Dictionary Entry Rule |
|--------------|----------------------|
| **Verb** | Only 3MS (`conjugation == '3MS'` and `lexeme_id == nil`) |
| **Noun** | Only singular (`number == 'singular'` and `lexeme_id == nil`) |
| **Adjective** | Only masculine singular (`gender == 'masculine'` and `number == 'singular'` and `lexeme_id == nil`) |
| **Participle** | Only masculine singular active (`gender == 'masculine'` and `number == 'singular'` and `aspect == 'active'` and `lexeme_id == nil`) |
| **Pronoun** | All pronouns (each is distinct) |
| **Functional words** | All (Prepositions, Articles, Particles, etc.) |
| **Consonant** | All consonants |

**Note:** Any word with `lexeme_id` present is never a dictionary entry (it's a linked word)

## Import vs Dictionary Display

**Important distinction:**

| Concept | What It Means |
|---------|--------------|
| **Import all words** | Every JSON entry becomes a Word record in the database |
| **Dictionary displays subset** | Only words where `is_dictionary_entry?` returns true appear in dictionary |
| **Standalone words** | Words with `lexeme_id: nil` (may or may not be dictionary entries) |
| **Linked words** | Words with `lexeme_id` pointing to another word (never dictionary entries) |

**Example:**
```json
// Import these 4 words:
[
  {"word": "לָמַד", "pos": "Verb", "pos_detail": {"conjugation": "3MS"}},           // → Dictionary ✓
  {"word": "לָמַדְתִּי", "pos": "Verb", "pos_detail": {"conjugation": "1CS"}},      // → Not in dictionary ✗
  {"word": "בַּ֫יִת", "pos": "Noun", "pos_detail": {"number": "singular"}},         // → Dictionary ✓
  {"word": "בָּתִּים", "pos": "Noun", "pos_detail": {"number": "plural"}}          // → Not in dictionary ✗
]

// Dictionary shows only: לָמַד, בַּ֫יִת (based on is_dictionary_entry? rules)
// But all 4 words exist in database and are searchable
```

## Structure

The import file is a JSON array of word objects:

```json
[
  {
    "word": "אִישׁ",
    "lesson_introduced": 1,
    "function": "a man",
    "glosses": ["man", "husband"],
    "pos_type": "Lexical Category",
    "pos": "Noun",
    "pos_detail": {
      "gender": "masculine",
      "number": "singular",
      "status": "absolute",
      "specific_type": null
    }
  },
  {
    // Next word...
  }
]
```

## Field Definitions

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `word` | string | Hebrew representation with nikkud | "אִישׁ" |
| `glosses` | array | English translations/definitions | ["man", "husband"] |
| `pos_type` | string | Category type: "Lexical Category" or "Functional Category" | "Lexical Category" |
| `pos` | string | Part of speech | "Noun", "Verb", "Adjective", etc. |
| `pos_detail` | object | Grammatical metadata (varies by POS) | See below |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `lesson_introduced` | number | Lesson number where word first appears | 1 |
| `function` | string | Functional description/translation | "a man" |
| `pronunciation_url` | string | URL to audio file | "https://example.com/audio/ish.mp3" |
| `picture_url` | string | URL to image | "https://example.com/images/ish.jpg" |
| `mnemonic` | string | Memory aid | "Think of 'ish' like English 'is'" |
| `lexeme_of_hint` | string | Hebrew representation of parent lexeme (for linking forms) | "בַּ֫יִת" |

## Part of Speech Details

### 1. Noun

```json
{
  "word": "מֶ֫לֶךְ",
  "lesson_introduced": 5,
  "function": "a king",
  "glosses": ["king"],
  "pos_type": "Lexical Category",
  "pos": "Noun",
  "pos_detail": {
    "gender": "masculine",           // Required: "masculine" or "feminine"
    "number": "singular",            // Required: "singular", "plural", "dual"
    "status": "absolute",            // Required: "absolute", "construct", "determined"
    "specific_type": null            // Optional: "collective", "epicene", "uncountable", "irregular plural"
  }
}
```

**Noun `pos_detail` Fields:**
- `gender`: "masculine" or "feminine" (required)
- `number`: "singular", "plural", or "dual" (required)
- `status`: "absolute", "construct", or "determined" (required)
- `specific_type`: null or one of:
  - "collective" (e.g., עַם - people)
  - "epicene" (same form for both genders)
  - "uncountable" (no plural form)
  - "irregular plural" (non-standard plural pattern)

**Import Strategy:**
- **Singular and plural are separate entries** (different representations: בַּ֫יִת vs בָּתִּים)
- Only singular (`number: "singular"`) appears in dictionary (if `lexeme_id` is null)
- Plural can optionally link to singular via `lexeme_of_hint` field
- Construct state is also a separate entry (different representation: בֵּית vs בַּ֫יִת)

### 2. Verb

```json
{
  "word": "לָמַד",
  "lesson_introduced": 8,
  "function": "to learn",
  "glosses": ["to learn", "to study"],
  "pos_type": "Lexical Category",
  "pos": "Verb",
  "pos_detail": {
    "root": "למד",                   // Required: 3-consonant root
    "binyan": "qal",                 // Required: verb pattern
    "aspect": "perfective",          // Required for conjugated forms
    "conjugation": "3MS",            // Required for conjugated forms
    "person": "3",                   // Required for conjugated forms
    "gender": "masculine",           // Required for conjugated forms
    "number": "singular",            // Required for conjugated forms
    "weakness": null                 // Optional: "1-Nun", "3-He", etc.
  }
}
```

**Verb `pos_detail` Fields:**
- `root`: 3-consonant Hebrew root (required)
- `binyan`: "qal", "niphal", "piel", "pual", "hiphil", "hophal", "hitpael" (required)
- `aspect`: "perfective", "imperfective", "imperative", "infinitive", "participle" (required for conjugated forms)
- `conjugation`: Combined person+gender+number code (e.g., "3MS", "1CS", "2FP") (required for conjugated forms)
- `person`: "1", "2", "3" (required for conjugated forms)
- `gender`: "masculine", "feminine", "common" (required for conjugated forms)
- `number`: "singular", "plural" (required for conjugated forms)
- `weakness`: null or weakness type:
  - "1-Nun" (נ as first radical)
  - "3-He" (ה as third radical)
  - "2-Vav (Hollow)" (ו/י as second radical)
  - "Geminate" (doubled second/third radical)

**Import Strategy:**
- **Each conjugation is a separate entry** (different representations: לָמַד vs לָמַדְתִּי)
- **Different binyans are separate entries** (different representations and meanings: לָמַד "to learn" vs לִמֵּד "to teach")
- Only 3MS (`conjugation: "3MS"`) appears in dictionary (if `lexeme_id` is null)
- Other conjugations can optionally link to 3MS via `lexeme_of_hint` field
- `root` field is optional - useful for grouping related words but not required

**Example - Different binyans (separate dictionary entries):**
```json
// Entry 1: למד Qal 3MS "to learn" - dictionary entry ✓
{
  "word": "לָמַד",
  "glosses": ["to learn"],
  "pos": "Verb",
  "pos_detail": {
    "root": "למד",
    "binyan": "qal",
    "conjugation": "3MS"
  }
}

// Entry 2: למד Piel 3MS "to teach" - different dictionary entry ✓
{
  "word": "לִמֵּד",
  "glosses": ["to teach"],
  "pos": "Verb",
  "pos_detail": {
    "root": "למד",
    "binyan": "piel",
    "conjugation": "3MS"
  }
}
```

**Example - Different conjugations (link to 3MS):**
```json
// Entry 1: למד Qal 3MS - dictionary entry ✓
{
  "word": "לָמַד",
  "glosses": ["to learn", "he learned"],
  "pos": "Verb",
  "pos_detail": {
    "binyan": "qal",
    "aspect": "perfective",
    "conjugation": "3MS"
  }
}

// Entry 2: למד Qal 1CS - linked word, not in dictionary ✗
{
  "word": "לָמַדְתִּי",
  "glosses": ["I learned"],
  "pos": "Verb",
  "lexeme_of_hint": "לָמַד",
  "pos_detail": {
    "binyan": "qal",
    "aspect": "perfective",
    "conjugation": "1CS"
  }
}
```

### 3. Adjective

```json
{
  "word": "גָּדוֹל",
  "lesson_introduced": 1,
  "function": "big/older",
  "glosses": ["big", "older"],
  "pos_type": "Lexical Category",
  "pos": "Adjective",
  "pos_detail": {
    "gender": "masculine",                    // Required: "masculine" or "feminine"
    "number": "singular",                     // Required: "singular" or "plural"
    "definiteness_agreement": "required",     // Optional: "required" or null
    "category": "descriptive"                 // Optional: "descriptive", "cardinal number", "ordinal number"
  }
}
```

**Adjective `pos_detail` Fields:**
- `gender`: "masculine" or "feminine" (required)
- `number`: "singular" or "plural" (required)
- `definiteness_agreement`: "required" or null (optional)
- `category`: null or one of:
  - "descriptive" (quality adjectives)
  - "cardinal number" (one, two, three)
  - "ordinal number" (first, second, third)

### 4. Participle

```json
{
  "word": "יֹשֵׁב",
  "lesson_introduced": 12,
  "function": "sitting/dwelling",
  "glosses": ["sitting", "dwelling", "inhabitant"],
  "pos_type": "Lexical Category",
  "pos": "Participle",
  "pos_detail": {
    "verbal_root": "ישב",        // Required: root verb
    "aspect": "active",          // Required: "active" or "passive"
    "gender": "masculine",       // Required: "masculine" or "feminine"
    "number": "singular"         // Required: "singular" or "plural"
  }
}
```

**Participle `pos_detail` Fields:**
- `verbal_root`: Hebrew root (required)
- `aspect`: "active" or "passive" (required)
- `gender`: "masculine" or "feminine" (required)
- `number`: "singular" or "plural" (required)

### 5. Pronouns

```json
{
  "word": "זֶה",
  "lesson_introduced": 1,
  "function": "this (m.s. demonstrative)",
  "glosses": ["this"],
  "pos_type": "Functional Category",
  "pos": "Pronoun",
  "pos_detail": {
    "sub_type": "Demonstrative",     // Required: pronoun type
    "gender": "masculine",           // Required: "masculine", "feminine", "common"
    "number": "singular",            // Required: "singular" or "plural"
    "person": "null"                 // Optional: "1st", "2nd", "3rd", or "null"
  }
}
```

**Pronoun Types (sub_type):**
- "Demonstrative" (this, that)
- "Personal" (I, you, he, she)
- "Interrogative" (who, which)
- "Relative" (who, which, that)
- "Indefinite" (someone, anyone)

**Pronoun `pos_detail` Fields:**
- `sub_type`: Type of pronoun (required)
- `gender`: "masculine", "feminine", "common" (required)
- `number`: "singular" or "plural" (required)
- `person`: "1st", "2nd", "3rd", or "null" (optional)

### 6. Interrogative Pronouns

```json
{
  "word": "מָה",
  "lesson_introduced": 1,
  "function": "what?",
  "glosses": ["what"],
  "pos_type": "Functional Category",
  "pos": "Interrogative Pronoun",
  "pos_detail": {
    "gender": "common",              // Required
    "number": "singular",            // Required
    "grammatical_role": "question word"  // Optional
  }
}
```

**Interrogative Pronoun `pos_detail` Fields:**
- `gender`: "masculine", "feminine", "common" (required)
- `number`: "singular" or "plural" (required)
- `grammatical_role`: Description of usage (optional)

### 7. Adverb/Particle

```json
{
  "word": "אַיֵּה",
  "lesson_introduced": 1,
  "function": "where? (used primarily with nouns/people)",
  "glosses": ["where"],
  "pos_type": "Functional Category",
  "pos": "Adverb/Particle",
  "pos_detail": {
    "gender": "common",                      // Optional
    "number": "singular",                    // Optional
    "grammatical_role": "interrogative adverb"  // Optional
  }
}
```

**Adverb/Particle `pos_detail` Fields:**
- `gender`: "masculine", "feminine", "common" (optional)
- `number`: "singular" or "plural" (optional)
- `grammatical_role`: Functional description (optional)
  - "interrogative adverb" (where, when, how)
  - "temporal adverb" (now, then, always)
  - "negation" (not, no)
  - "affirmation" (yes, indeed)

### 8. Preposition

```json
{
  "word": "לְ",
  "lesson_introduced": 2,
  "function": "to/for",
  "glosses": ["to", "for"],
  "pos_type": "Functional Category",
  "pos": "Preposition",
  "pos_detail": {
    "grammatical_role": "inseparable prefix",  // Optional
    "status": "prefix"                         // Optional
  }
}
```

**Preposition `pos_detail` Fields:**
- `grammatical_role`: "inseparable prefix", "independent preposition", etc. (optional)
- `status`: "prefix", "independent", "suffixed" (optional)

### 9. Conjunction

```json
{
  "word": "וְ",
  "lesson_introduced": 2,
  "function": "and",
  "glosses": ["and"],
  "pos_type": "Functional Category",
  "pos": "Conjunction",
  "pos_detail": {
    "grammatical_role": "coordinating conjunction",  // Optional
    "status": "prefix"                               // Optional
  }
}
```

**Conjunction `pos_detail` Fields:**
- `grammatical_role`: "coordinating conjunction", "subordinating conjunction" (optional)
- `status`: "prefix", "independent" (optional)

### 10. Article

```json
{
  "word": "הַ",
  "lesson_introduced": 3,
  "function": "the (definite article)",
  "glosses": ["the"],
  "pos_type": "Functional Category",
  "pos": "Article",
  "pos_detail": {
    "grammatical_role": "definite article",
    "status": "prefix"
  }
}
```

**Article `pos_detail` Fields:**
- `grammatical_role`: "definite article", "indefinite article" (optional)
- `status`: "prefix", "independent" (optional)

### 11. Particle (General)

```json
{
  "word": "אֶת־",
  "lesson_introduced": 4,
  "function": "(direct object marker)",
  "glosses": ["(direct object marker)"],
  "pos_type": "Functional Category",
  "pos": "Particle",
  "pos_detail": {
    "grammatical_role": "object marker",
    "function": "Marks definite direct objects"
  }
}
```

**Particle `pos_detail` Fields:**
- `grammatical_role`: Functional description (optional)
- `function`: Detailed grammatical explanation (optional)

### 12. Consonant

```json
{
  "word": "א",
  "lesson_introduced": 0,
  "function": "alef (silent consonant)",
  "glosses": ["alef"],
  "pos_type": "Functional Category",
  "pos": "Consonant",
  "pos_detail": {
    "name": "alef",
    "transliteration": "'",
    "status": "guttural"
  }
}
```

**Consonant `pos_detail` Fields:**
- `name`: Hebrew letter name (optional)
- `transliteration`: Romanization (optional)
- `status`: "begadkefat", "guttural", "sofit", etc. (optional)

## Import Mapping

### Database Field Mapping

| JSON Field | Database Column | Notes |
|------------|----------------|-------|
| `word` | `representation` | Hebrew text with nikkud |
| `glosses` | → `glosses` table | Create Gloss records |
| `pos` | `part_of_speech_category_id` | Look up by name |
| `pos_type` | `form_metadata.pos_type` | Stored in JSONB |
| `pos_detail` | `form_metadata` | Entire object merged into JSONB |
| `lesson_introduced` | `form_metadata.lesson_introduced` | Include in JSONB |
| `function` | `form_metadata.function` | Include in JSONB |
| `lexeme_of_hint` | `lexeme_id` | Look up word by representation, set lexeme_id |
| `pronunciation_url` | `pronunciation_url` | Direct column |
| `picture_url` | `picture_url` | Direct column |
| `mnemonic` | `mnemonic` | Direct column |

### Special Handling

1. **Lexeme Linking**:
   - If `lexeme_of_hint` is present, look up word by `representation`
   - If found, set `lexeme_id` to that word's ID
   - If not found, leave `lexeme_id` as NULL (can link later)

2. **Part of Speech Category**:
   - Look up existing category by `pos` field
   - Map to existing categories:
     - "Noun" → noun category
     - "Verb" → verb category
     - "Adjective" → adjective category
     - "Participle" → participle category
     - "Pronoun" → pronoun category
     - "Interrogative Pronoun" → interrogative category
     - "Adverb/Particle" → adverb/particle category
     - "Preposition" → preposition category
     - "Conjunction" → conjunction category
     - "Article" → article category
     - "Particle" → particle category
     - "Consonant" → consonant category

3. **Metadata Merging**:
   - Merge `pos_detail`, `pos_type`, `lesson_introduced`, and `function` into single `form_metadata` JSONB object
   - All grammatical fields (gender, number, status, etc.) stored as strings in JSONB
   - All fields remain queryable via JSONB operators

## Import Process

### Step-by-Step Import

```ruby
# Import controller pseudocode
def import_from_json(json_array)
  ActiveRecord::Base.transaction do
    json_array.each do |entry|
      # 1. Find part of speech category
      pos_category = PartOfSpeechCategory.find_by(name: entry['pos'])

      # 2. Build metadata object (merge all metadata fields)
      metadata = (entry['pos_detail'] || {}).dup
      metadata['pos_type'] = entry['pos_type'] if entry['pos_type']
      metadata['lesson_introduced'] = entry['lesson_introduced'] if entry['lesson_introduced']
      metadata['function'] = entry['function'] if entry['function']

      # 3. Try to find parent lexeme if hint provided
      lexeme_id = nil
      if entry['lexeme_of_hint'].present?
        parent = Word.find_by(representation: entry['lexeme_of_hint'])
        lexeme_id = parent&.id
      end

      # 4. Create word
      word = Word.create!(
        representation: entry['word'],
        lexeme_id: lexeme_id,
        part_of_speech_category: pos_category,
        form_metadata: metadata,
        pronunciation_url: entry['pronunciation_url'],
        picture_url: entry['picture_url'],
        mnemonic: entry['mnemonic']
      )

      # 5. Create glosses
      entry['glosses'].each do |gloss_text|
        word.glosses.create!(text: gloss_text)
      end
    end
  end
end
```

## Validation Rules

### Required Fields Validation
- `word` must be present and non-empty
- `glosses` must be an array with at least one entry
- `pos` must match an existing part of speech category
- `pos_detail` must be present (can be empty object for some POS)

### Data Type Validation
- `word`: UTF-8 string (Hebrew with nikkud)
- `glosses`: Array of non-empty strings
- `lesson_introduced`: Integer or null
- `function`: String or null
- `pos_type`: String (informational, not stored)
- `pos`: String matching POS category
- `pos_detail`: Object (stored as JSONB)

## Error Handling

Provide clear error messages for invalid data:

```json
{
  "errors": [
    {
      "line": 42,
      "word": "שָׁלוֹם",
      "field": "pos",
      "error": "Part of speech 'Nown' not found. Did you mean 'Noun'?"
    },
    {
      "line": 43,
      "word": "אִישׁ",
      "field": "glosses",
      "error": "Glosses array is empty"
    }
  ]
}
```

## Complete Examples

### Noun Example
```json
{
  "word": "אִישׁ",
  "lesson_introduced": 1,
  "function": "a man",
  "glosses": ["man", "husband"],
  "pos_type": "Lexical Category",
  "pos": "Noun",
  "pos_detail": {
    "gender": "masculine",
    "number": "singular",
    "status": "absolute",
    "specific_type": null
  }
}
```

### Verb Example
```json
{
  "word": "לָמַד",
  "lesson_introduced": 8,
  "function": "to learn",
  "glosses": ["to learn", "to study"],
  "pos_type": "Lexical Category",
  "pos": "Verb",
  "pos_detail": {
    "root": "למד",
    "binyan": "qal",
    "aspect": "perfective",
    "conjugation": "3MS",
    "person": "3",
    "gender": "masculine",
    "number": "singular",
    "weakness": null
  }
}
```

### Adjective Example
```json
{
  "word": "גָּדוֹל",
  "lesson_introduced": 1,
  "function": "big/older",
  "glosses": ["big", "older"],
  "pos_type": "Lexical Category",
  "pos": "Adjective",
  "pos_detail": {
    "gender": "masculine",
    "number": "singular",
    "definiteness_agreement": "required",
    "category": "descriptive"
  }
}
```

### Pronoun Example
```json
{
  "word": "זֶה",
  "lesson_introduced": 1,
  "function": "this (m.s. demonstrative)",
  "glosses": ["this"],
  "pos_type": "Functional Category",
  "pos": "Pronoun",
  "pos_detail": {
    "sub_type": "Demonstrative",
    "gender": "masculine",
    "number": "singular",
    "person": "null"
  }
}
```

### Linked Words Example (with lexeme_of_hint)

**Singular noun (will be dictionary entry):**
```json
{
  "word": "בַּ֫יִת",
  "lesson_introduced": 5,
  "function": "a house",
  "glosses": ["house", "temple"],
  "pos_type": "Lexical Category",
  "pos": "Noun",
  "pos_detail": {
    "gender": "masculine",
    "number": "singular",
    "status": "absolute",
    "specific_type": null
  }
}
```

**Plural noun (linked to singular):**
```json
{
  "word": "בָּתִּים",
  "lesson_introduced": 5,
  "function": "houses",
  "glosses": ["houses"],
  "pos_type": "Lexical Category",
  "pos": "Noun",
  "lexeme_of_hint": "בַּ֫יִת",
  "pos_detail": {
    "gender": "masculine",
    "number": "plural",
    "status": "absolute",
    "specific_type": "irregular plural"
  }
}
```

**After import:**
- בַּ֫יִת will have `lexeme_id: null` → `is_dictionary_entry?` returns true (singular noun)
- בָּתִּים will have `lexeme_id` pointing to בַּ֫יִת → `is_dictionary_entry?` returns false (has lexeme_id)
- Dictionary shows only בַּ֫יִת
- בַּ֫יִת's word detail page shows בָּתִּים as a linked word
- Visiting `/words/:id` for בָּתִּים redirects to בַּ֫יִת's page with anchor

## Future Extensions

The JSONB `form_metadata` approach allows adding new fields without database changes:

1. **Frequency data**: `"frequency_rank": 150`
2. **Semantic domains**: `"semantic_domain": "animals"`
3. **Etymology**: `"cognates": ["Arabic rajul", "Aramaic gabar"]`
4. **Usage notes**: `"biblical_only": true`
5. **Related words**: `"related_lexeme_ids": [42, 97]`

Simply add new fields to `pos_detail` or as top-level fields - the importer will store them in the JSONB column.

---

## Summary

### Key Takeaways

1. **One word = One JSON entry**
   - Each unique representation (singular, plural, 3MS, 1CS, etc.) is a separate JSON object
   - Not nested - flat structure for simplicity

2. **Dictionary display is computed**
   - Not a field in the JSON
   - Determined by `is_dictionary_entry?` method in Ruby code
   - Based on POS category + metadata (e.g., verbs: only 3MS, nouns: only singular)

3. **Linking is optional**
   - Use `lexeme_of_hint` to link related words (plural → singular, 1CS → 3MS)
   - If parent not found during import, word remains standalone
   - Can link later via UI

4. **Metadata is flexible**
   - All grammatical data goes in `pos_detail` object
   - Stored as JSONB in database
   - Add new fields anytime without migrations

5. **Database columns are minimal**
   - Only `part_of_speech_category_id` as a foreign key
   - Everything else in `form_metadata` JSONB
   - Querying: `Word.where("form_metadata->>'gender' = ?", 'masculine')`

### Import Checklist

Before importing, verify:
- [ ] Each word has unique `representation` (don't duplicate)
- [ ] All required fields present (`word`, `glosses`, `pos`, `pos_detail`)
- [ ] POS matches existing categories (Noun, Verb, Adjective, etc.)
- [ ] Metadata fields appropriate for POS (e.g., verbs have `conjugation`, nouns have `number`)
- [ ] `lexeme_of_hint` references an existing word (if used)
- [ ] Dictionary entry words have appropriate metadata (singular nouns, 3MS verbs, etc.)
