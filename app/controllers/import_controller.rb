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
      result = import_words(parsed_data)

      if result[:errors] > 0
        redirect_to root_path, notice: "Import completed: #{result[:success]} words imported, #{result[:errors]} errors (check logs for details)"
      else
        redirect_to root_path, notice: "Successfully imported #{result[:success]} words with their glosses"
      end
    rescue DictionaryImportParser::ParseError => e
      render :new, status: :unprocessable_entity, locals: { error: e.message }
    end
  end

  def import_story
    authorize :import

    # Sanitize filename to prevent path traversal attacks
    filename = sanitize_filename(params[:filename])

    unless filename
      redirect_to new_import_path, alert: "Invalid filename"
      return
    end

    file_path = Rails.root.join("stories", "#{filename}.json")

    unless File.exist?(file_path)
      redirect_to new_import_path, alert: "Story file not found: #{filename}.json"
      return
    end

    begin
      json_data = JSON.parse(File.read(file_path)) # brakeman:ignore:FileAccess

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

  private

  def import_words(parsed_data)
    unknown_pos = PartOfSpeechCategory.find_by(abbrev: "?")
    success_count = 0
    error_count = 0

    parsed_data.each do |entry|
      begin
        ActiveRecord::Base.transaction do
          # Check if this is JSON format (has pos field) or text format
          if entry[:pos].present?
            import_json_word(entry, unknown_pos)
          else
            import_text_word(entry, unknown_pos)
          end
          success_count += 1
        end
      rescue => e
        error_count += 1
        Rails.logger.error "Failed to import word '#{entry[:representation]}': #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    { success: success_count, errors: error_count }
  end

  def import_json_word(entry, unknown_pos)
    # Find part of speech category by name
    pos_category = PartOfSpeechCategory.find_by(name: entry[:pos])
    if pos_category.nil?
      Rails.logger.warn "Part of speech '#{entry[:pos]}' not found for word '#{entry[:representation]}', using 'Unknown'"
      pos_category = unknown_pos
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

  def sanitize_filename(filename)
    return nil if filename.blank?

    # Remove any directory components (prevent path traversal)
    basename = File.basename(filename)

    # Only allow alphanumeric characters, hyphens, and underscores
    # This prevents any path traversal attempts or special characters
    return nil unless basename.match?(/\A[a-zA-Z0-9_-]+\z/)

    basename
  end
end
