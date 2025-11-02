class WordsController < ApplicationController
  before_action :set_word, only: %i[ show edit update destroy ]

  # GET /words or /words.json
  def index
    authorize Word
    @words = Word.includes(:decks, :glosses).page(params[:page]).per(25)
  end

  # GET /words/1 or /words/1.json
  def show
    authorize @word

    # If this is a form (has lexeme_id), redirect to its parent word with anchor
    if @word.lexeme_id.present?
      redirect_to word_path(@word.lexeme, anchor: "form-#{@word.id}"), status: :moved_permanently
      return
    end

    # Load all forms linked to this word, grouped by type
    @forms = @word.forms.includes(:glosses).to_a

    # Build back URL based on return_to parameter
    @back_url = if params[:return_to] == "dictionary" && session[:dictionary_filters].present?
      dictionary_path(session[:dictionary_filters])
    elsif params[:return_to] == "dictionary"
      dictionary_path
    else
      words_path
    end
  end

  # GET /words/new
  def new
    @word = Word.new
    load_form_data
    authorize @word
  end

  # GET /words/1/edit
  def edit
    load_form_data
    authorize @word

    # Build back URL based on return_to parameter
    @back_url = if params[:return_to] == "dictionary" && session[:dictionary_filters].present?
      dictionary_path(session[:dictionary_filters])
    elsif params[:return_to] == "dictionary"
      dictionary_path
    else
      word_path(@word)
    end
  end

  # POST /words or /words.json
  def create
    @word = Word.new(word_params)
    authorize @word

    respond_to do |format|
      if @word.save
        format.html { redirect_to @word, notice: "Word was successfully created." }
        format.json { render :show, status: :created, location: @word }
      else
        load_form_data
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @word.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /words/1 or /words/1.json
  def update
    authorize @word
    respond_to do |format|
      if @word.update(word_params)
        # Redirect back to dictionary with filters if that's where we came from
        redirect_url = if params[:return_to] == "dictionary" && session[:dictionary_filters].present?
          dictionary_path(session[:dictionary_filters])
        elsif params[:return_to] == "dictionary"
          dictionary_path
        else
          @word
        end

        format.html { redirect_to redirect_url, notice: "Word was successfully updated." }
        format.json { render :show, status: :ok, location: @word }
      else
        load_form_data
        @back_url = if params[:return_to] == "dictionary" && session[:dictionary_filters].present?
          dictionary_path(session[:dictionary_filters])
        elsif params[:return_to] == "dictionary"
          dictionary_path
        else
          word_path(@word)
        end
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @word.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /words/1 or /words/1.json
  def destroy
    authorize @word
    @word.destroy!

    respond_to do |format|
      format.html { redirect_to words_path, status: :see_other, notice: "Word was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word
      @word = Word.includes(:glosses, :decks).find(params.expect(:id))
    end

    # Load data needed for the form
    def load_form_data
      @decks = current_user.superuser? ? Deck.all : current_user.decks
      @pos_categories = PartOfSpeechCategory.all.order(:name)
    end

    # Only allow a list of trusted parameters through.
    def word_params
      params.expect(word: [
        :representation,
        :part_of_speech_category_id,
        :mnemonic,
        :pronunciation_url,
        :picture_url,
        :lexeme_id,
        :conjugation,
        :binyan,
        :aspect,
        :person,
        :number,
        :status,
        :root,
        :weakness,
        deck_ids: []
      ])
    end
end
