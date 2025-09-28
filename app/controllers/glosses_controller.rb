class GlossesController < ApplicationController
  before_action :set_gloss, only: %i[ show edit update destroy ]

  # GET /glosses or /glosses.json
  def index
    @glosses = Gloss.all
  end

  # GET /glosses/1 or /glosses/1.json
  def show
  end

  # GET /glosses/new
  def new
    @gloss = Gloss.new
  end

  # GET /glosses/1/edit
  def edit
  end

  # POST /glosses or /glosses.json
  def create
    @gloss = Gloss.new(gloss_params)

    respond_to do |format|
      if @gloss.save
        format.html { redirect_to @gloss, notice: "Gloss was successfully created." }
        format.json { render :show, status: :created, location: @gloss }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @gloss.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /glosses/1 or /glosses/1.json
  def update
    respond_to do |format|
      if @gloss.update(gloss_params)
        format.html { redirect_to @gloss, notice: "Gloss was successfully updated." }
        format.json { render :show, status: :ok, location: @gloss }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @gloss.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /glosses/1 or /glosses/1.json
  def destroy
    @gloss.destroy!

    respond_to do |format|
      format.html { redirect_to glosses_path, status: :see_other, notice: "Gloss was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_gloss
      @gloss = Gloss.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def gloss_params
      params.expect(gloss: [ :text, :word_id ])
    end
end
