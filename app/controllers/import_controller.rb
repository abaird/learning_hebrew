class ImportController < ApplicationController
  before_action :authenticate_user!

  def new
    authorize :import
  end

  def create
    authorize :import

    unless params[:file].present?
      render :new, status: :unprocessable_entity, locals: { error: "No file provided" }
      return
    end

    file_content = params[:file].read.force_encoding("UTF-8")
    parser = DictionaryImportParser.new(file_content)

    begin
      parsed_data = parser.parse
      import_words(parsed_data)

      redirect_to root_path, notice: "Successfully imported #{parsed_data.length} words with their glosses"
    rescue DictionaryImportParser::ParseError => e
      render :new, status: :unprocessable_entity, locals: { error: e.message }
    end
  end

  private

  def import_words(parsed_data)
    unknown_pos = PartOfSpeechCategory.find_by(abbrev: "?")

    ActiveRecord::Base.transaction do
      parsed_data.each do |entry|
        # Check if this is JSON format (has pos field) or text format
        if entry[:pos].present?
          import_json_word(entry)
        else
          import_text_word(entry, unknown_pos)
        end
      end
    end
  end

  def import_json_word(entry)
    # Find part of speech category by name
    pos_category = PartOfSpeechCategory.find_by(name: entry[:pos])
    if pos_category.nil?
      raise DictionaryImportParser::ParseError, "Part of speech '#{entry[:pos]}' not found"
    end

    # Try to find parent lexeme if hint provided
    lexeme_id = nil
    if entry[:lexeme_of_hint].present?
      parent = Word.find_by(representation: entry[:lexeme_of_hint])
      lexeme_id = parent&.id
    end

    # Find or create word
    word = Word.find_or_initialize_by(representation: entry[:representation])

    # Set attributes
    word.part_of_speech_category = pos_category
    word.lexeme_id = lexeme_id
    word.form_metadata = entry[:form_metadata] || {}
    word.pronunciation_url = entry[:pronunciation_url] if entry[:pronunciation_url].present?
    word.picture_url = entry[:picture_url] if entry[:picture_url].present?
    word.mnemonic = entry[:mnemonic] if entry[:mnemonic].present?

    word.save!

    # Replace all existing glosses with new ones
    word.glosses.destroy_all
    entry[:glosses].each do |gloss_text|
      word.glosses.create!(text: gloss_text)
    end
  end

  def import_text_word(entry, unknown_pos)
    # Original text format import (backward compatibility)
    word = Word.find_or_initialize_by(representation: entry[:representation])
    if word.new_record?
      word.part_of_speech_category = unknown_pos
    end
    word.save!

    # Replace all existing glosses with new ones
    word.glosses.destroy_all
    entry[:glosses].each do |gloss_text|
      word.glosses.create!(text: gloss_text)
    end
  end
end
