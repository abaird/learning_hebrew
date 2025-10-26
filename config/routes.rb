Rails.application.routes.draw do
  resources :glosses
  resources :words
  resources :decks
  devise_for :users

  # Stories
  resources :stories, only: [ :index, :show ]

  # API endpoints
  namespace :api do
    get "dictionary/lookup", to: "dictionary#lookup"
  end

  # Dictionary import (superuser only)
  get "import", to: "import#new", as: :new_import
  post "import", to: "import#create", as: :import
  post "import/story", to: "import#import_story", as: :import_story
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Dictionary as homepage
  root "dictionary#index"
  get "dictionary", to: "dictionary#index", as: :dictionary

  get "/logout", to: "sessions#logout"
end
