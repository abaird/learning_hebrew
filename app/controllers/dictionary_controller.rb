class DictionaryController < ApplicationController
  def index
    # Determine show_all value: use param, then session, then default to true
    @show_all = if params.key?(:show_all)
      params[:show_all] == "true"
    elsif session[:dictionary_filters]&.key?("show_all")
      session[:dictionary_filters]["show_all"] == "true"
    else
      true  # Default to showing all words
    end

    # Store search params in session for later use (include computed show_all)
    filter_params = params.permit(:q, :pos_id, :binyan, :number, :lesson, :lesson_mode, :show_all, :page, :commit).to_h
    filter_params["show_all"] = @show_all.to_s
    session[:dictionary_filters] = filter_params

    # Start with base query
    words = Word.includes(:glosses, :part_of_speech_category)

    # Apply search filter if present
    if params[:q].present?
      query = params[:q].strip
      normalized_query = Word.normalize_hebrew(query)

      # Search in representation (normalized) and glosses
      # Normalize by: 1) removing diacriticals, 2) converting final forms to regular
      normalized_representation = "translate(regexp_replace(words.representation, '[\\u0591-\\u05AF\\u05B0-\\u05BD\\u05BF-\\u05C2\\u05C4-\\u05C5\\u05C7]', '', 'g'), 'ךםןףץ', 'כמנפצ')"

      words = words.left_joins(:glosses)
                   .where(
                     "#{normalized_representation} ILIKE ? OR glosses.text ILIKE ?",
                     "%#{normalized_query}%",
                     "%#{query}%"
                   )
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

    # Filter by dictionary entries in SQL (unless show_all is true)
    unless @show_all
      words = words.where(is_dictionary_entry: true)
    end

    # Apply alphabetical sorting and convert to array
    # Note: alphabetically scope requires loading to memory for Hebrew sorting
    all_words = words.alphabetically.to_a

    # Paginate results
    @words = Kaminari.paginate_array(all_words).page(params[:page]).per(25)

    # Load filter options for the view
    @pos_categories = PartOfSpeechCategory.all.order(:name)
    @binyans = [ "qal", "niphal", "piel", "pual", "hiphil", "hophal", "hitpael" ]
    @numbers = [ "singular", "plural", "dual" ]
  end
end
