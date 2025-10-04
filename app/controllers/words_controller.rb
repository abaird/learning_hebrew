class WordsController < ApplicationController
  before_action :set_word, only: %i[ show edit update destroy ]

  # GET /words or /words.json
  def index
    authorize Word
    @words = Word.all
  end

  # GET /words/1 or /words/1.json
  def show
    authorize @word
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
        format.html { redirect_to @word, notice: "Word was successfully updated." }
        format.json { render :show, status: :ok, location: @word }
      else
        load_form_data
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
      @word = Word.find(params.expect(:id))
    end

    # Load data needed for the form
    def load_form_data
      @decks = current_user.superuser? ? Deck.all : current_user.decks
      @pos_categories = PartOfSpeechCategory.all.order(:name)
      @genders = Gender.all.order(:name)
      @verb_forms = VerbForm.all.order(:name)
    end

    # Only allow a list of trusted parameters through.
    def word_params
      params.expect(word: [ :representation, :part_of_speech_category_id, :gender_id, :verb_form_id, :mnemonic, :pronunciation_url, :picture_url, deck_ids: [] ])
    end
end
