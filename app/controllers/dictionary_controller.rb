class DictionaryController < ApplicationController
  def index
    # Get only dictionary entry words (3MS verbs, singular non-construct nouns, etc.)
    # Load all words with associations first, then filter
    all_words = Word.where(lexeme_id: nil)
                    .includes(:glosses, :part_of_speech_category)
                    .alphabetically
                    .select { |w| w.is_dictionary_entry? }

    # Convert to array for Kaminari pagination
    @words = Kaminari.paginate_array(all_words).page(params[:page]).per(25)
  end
end
