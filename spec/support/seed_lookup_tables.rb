# Seed lookup tables for tests
RSpec.configure do |config|
  config.before(:suite) do
    # Create part of speech categories
    pos_categories = [
      { name: "Noun", abbrev: "n" },
      { name: "Verb", abbrev: "v" },
      { name: "Adjective", abbrev: "adj" },
      { name: "Adverb", abbrev: "adv" },
      { name: "Pronoun", abbrev: "pron" },
      { name: "Preposition", abbrev: "prep" },
      { name: "Conjunction", abbrev: "conj" },
      { name: "Particle", abbrev: "part" },
      { name: "Interjection", abbrev: "interj" },
      { name: "Numeral", abbrev: "num" },
      { name: "Unknown", abbrev: "?" }
    ]

    pos_categories.each do |category|
      PartOfSpeechCategory.find_or_create_by!(abbrev: category[:abbrev]) do |pos|
        pos.name = category[:name]
      end
    end

    # Create genders
    genders = [
      { name: "Masculine", abbrev: "m" },
      { name: "Feminine", abbrev: "f" },
      { name: "Common", abbrev: "c" }
    ]

    genders.each do |gender_data|
      Gender.find_or_create_by!(abbrev: gender_data[:abbrev]) do |gender|
        gender.name = gender_data[:name]
      end
    end

    # Create verb forms
    verb_forms = [
      { name: "Infinitive", abbrev: "inf" },
      { name: "Imperative", abbrev: "imp" },
      { name: "Qatal (Perfect)", abbrev: "qal" },
      { name: "Yiqtol (Imperfect)", abbrev: "yiq" },
      { name: "Participle", abbrev: "ptcp" },
      { name: "Cohortative", abbrev: "coh" },
      { name: "Jussive", abbrev: "juss" }
    ]

    verb_forms.each do |form_data|
      VerbForm.find_or_create_by!(abbrev: form_data[:abbrev]) do |form|
        form.name = form_data[:name]
      end
    end
  end
end
