require 'rails_helper'

RSpec.describe "Navigation", type: :request do
  fixtures :users, :decks, :words

  let(:regular_user) { users(:test_user) }
  let(:superuser) { users(:superuser) }

  describe "Unauthenticated user navigation" do
    it "redirects to sign in page when accessing protected routes" do
      get words_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows sign in link on root page" do
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign in")
    end
  end

  describe "Authenticated regular user navigation" do
    before { sign_in regular_user }

    it "shows navigation with user-specific links" do
      get words_path
      expect(response).to be_successful
      expect(response.body).to include("Words")
      expect(response.body).to include("Decks")
      expect(response.body).to include("Sign out")
    end

    it "can navigate to words index" do
      get words_path
      expect(response).to be_successful
      expect(response.body).to include("Words")
    end

    it "can navigate to decks index" do
      get decks_path
      expect(response).to be_successful
      expect(response.body).to include("Decks")
    end

    it "can navigate to glosses index" do
      get glosses_path
      expect(response).to be_successful
      expect(response.body).to include("Glosses")
    end

    it "shows user email in navigation" do
      get words_path
      expect(response.body).to include(regular_user.email)
    end
  end

  describe "Authenticated superuser navigation" do
    before { sign_in superuser }

    it "shows superuser badge in navigation" do
      get words_path
      expect(response).to be_successful
      expect(response.body).to include("Superuser")
    end

    it "can access all routes" do
      get words_path
      expect(response).to be_successful

      get decks_path
      expect(response).to be_successful

      get glosses_path
      expect(response).to be_successful
    end
  end

  describe "Sign out flow" do
    before { sign_in regular_user }

    it "signs out user and redirects to root" do
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "Navigation links presence" do
    before { sign_in regular_user }

    it "includes all main navigation links" do
      get words_path

      expect(response.body).to include('href="/words"')
      expect(response.body).to include('href="/decks"')
      expect(response.body).to include('href="/glosses"')
    end
  end
end
