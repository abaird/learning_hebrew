class StoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @stories = Story.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @story = Story.find_by(slug: params[:id])

    unless @story
      redirect_to stories_path, alert: "Story not found"
      return
    end

    @title = @story.title
    @verses = @story.verses
  end
end
