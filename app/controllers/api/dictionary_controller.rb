module Api
  class DictionaryController < ApplicationController
    skip_before_action :verify_authenticity_token

    def lookup
      word = params[:word]

      if word.blank?
        render json: { error: "Word parameter required" }, status: :bad_request
        return
      end

      result = DictionaryLookupService.lookup(word)
      render json: result
    end
  end
end
