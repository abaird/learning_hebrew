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

    file_content = params[:file].read.force_encoding('UTF-8')
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
    ActiveRecord::Base.transaction do
      parsed_data.each do |entry|
        # Find or create word (checking for exact match including nikkud)
        word = Word.find_or_initialize_by(representation: entry[:representation])
        word.part_of_speech = 'unknown' if word.new_record?
        word.save!

        # Replace all existing glosses with new ones
        word.glosses.destroy_all
        entry[:glosses].each do |gloss_text|
          word.glosses.create!(text: gloss_text)
        end
      end
    end
  end
end
