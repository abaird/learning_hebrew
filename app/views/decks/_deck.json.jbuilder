json.extract! deck, :id, :name, :description, :user_id, :created_at, :updated_at
json.url deck_url(deck, format: :json)
