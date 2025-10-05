class DictionaryController < ApplicationController
  def index
    # Start with base query
    words = Word.includes(:glosses, :part_of_speech_category)

    # Apply search filter if present
    if params[:q].present?
      query = params[:q].strip
      # Search in representation and glosses
      words = words.left_joins(:glosses)
                   .where("words.representation ILIKE ? OR glosses.text ILIKE ?", "%#{query}%", "%#{query}%")
                   .distinct
    end

    # Apply POS filter if present
    if params[:pos_id].present?
      words = words.where(part_of_speech_category_id: params[:pos_id])
    end

    # Apply binyan filter if present
    if params[:binyan].present?
      words = words.where("form_metadata->>'binyan' = ?", params[:binyan])
    end

    # Apply number filter if present
    if params[:number].present?
      words = words.where("form_metadata->>'number' = ?", params[:number])
    end

    # Apply lesson filter if present
    if params[:lesson].present?
      if params[:lesson_mode] == "or_less"
        # Filter by lesson number or less
        words = words.where("(form_metadata->>'lesson_introduced')::integer <= ?", params[:lesson].to_i)
      else
        # Filter by exact lesson number
        words = words.where("form_metadata->>'lesson_introduced' = ?", params[:lesson])
      end
    end

    # Apply alphabetical sorting and convert to array
    all_words = words.alphabetically.to_a

    # Filter by dictionary entries unless show_all is true
    unless params[:show_all] == "true"
      all_words = all_words.select { |w| w.is_dictionary_entry? }
    end

    # Paginate results
    @words = Kaminari.paginate_array(all_words).page(params[:page]).per(25)

    # Load filter options for the view
    @pos_categories = PartOfSpeechCategory.all.order(:name)
    @binyans = [ "qal", "niphal", "piel", "pual", "hiphil", "hophal", "hitpael" ]
    @numbers = [ "singular", "plural", "dual" ]
  end
end
