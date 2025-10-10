# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create superuser in development with simple password
superuser = User.find_or_create_by(email: 'abaird@bairdsnet.net') do |user|
  user.password = Rails.env.production? ? ENV['SUPERUSER_PASSWORD'] : 'secret!'
  user.superuser = true
end

puts "Superuser created: #{superuser.email}"

# Create part of speech categories
pos_categories = [
  { name: "Noun", abbrev: "n" },
  { name: "Phrase", abbrev: "phrase" },
  { name: "Proper Noun", abbrev: "pr. n" },
  { name: "Verb", abbrev: "v" },
  { name: "Adjective", abbrev: "adj" },
  { name: "Adverb/Participle", abbrev: "adv" },
  { name: "Pronoun", abbrev: "pron" },
  { name: "Interrogative Pronoun", abbrev: "int. pron" },
  { name: "Preposition", abbrev: "prep" },
  { name: "Conjunction", abbrev: "conj" },
  { name: "Particle", abbrev: "part" },
  { name: "Interjection", abbrev: "interj" },
  { name: "Numeral", abbrev: "num" },
  { name: "Consonant", abbrev: "cons" },
  { name: "Possessive Suffix", abbrev: "poss. suf" },
  { name: "Quantifier", abbrev: "quant" },
  { name: "Unknown", abbrev: "?" }
]

pos_categories.each do |category|
  PartOfSpeechCategory.find_or_create_by!(abbrev: category[:abbrev]) do |pos|
    pos.name = category[:name]
  end
end

puts "Created #{PartOfSpeechCategory.count} part of speech categories"

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

puts "Created #{Gender.count} genders"

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

puts "Created #{VerbForm.count} verb forms"
