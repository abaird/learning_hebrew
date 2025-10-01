class DictionaryController < ApplicationController
  def index
    # Get all words with glosses, sorted by Hebrew alphabet
    all_words = Word.includes(:glosses).alphabetically

    # Convert to array for Kaminari pagination
    @words = Kaminari.paginate_array(all_words).page(params[:page]).per(25)
  end
end
