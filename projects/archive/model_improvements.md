# Implementation Plan: Better User Management and Model Restructuring

## Overview
Transform the Hebrew learning application from a hierarchical model (User → Deck → Word → Gloss) to a more flexible many-to-many relationship (User → Deck, Word ↔ Deck, Word → Gloss) with superuser functionality, proper authorization, and improved form UX.

## Phase 1: Database Schema Changes (SIMPLIFIED)

### 1.1 Create Join Table for Deck-Word Many-to-Many Relationship
**Goal**: Enable words to belong to multiple decks and decks to contain multiple words

**Migration Steps**:
```ruby
# Create deck_words join table
rails generate migration CreateDeckWords deck:references word:references
```

**Schema Changes**:
- Create `deck_words` table with:
  - `deck_id` (foreign key to decks)
  - `word_id` (foreign key to words)
  - `created_at`, `updated_at`
  - Unique index on `[deck_id, word_id]`

### 1.2 Remove deck_id from Words Table
**Goal**: Remove direct foreign key relationship between words and decks

**Migration Steps**:
```ruby
# Remove deck_id column from words table
rails generate migration RemoveDeckIdFromWords deck:references
```

### 1.3 Add Superuser Flag to Users
**Goal**: Add administrative capabilities to user model

**Migration Steps**:
```ruby
# Add superuser boolean to users
rails generate migration AddSuperuserToUsers superuser:boolean
```

**Schema Changes**:
- Add `superuser` boolean column to users table (default: false)

### 1.4 Database Reset Strategy
**SIMPLIFIED APPROACH**: Since no important data exists, we can:
- Reset the database completely: `rails db:reset`
- No complex data migration needed
- Fresh start with new schema

## Phase 2: Model Updates

### 2.1 Update Model Associations
**Files to Modify**:
- `app/models/deck.rb`
- `app/models/word.rb`
- `app/models/user.rb`

**Changes**:
```ruby
# app/models/deck.rb
class Deck < ApplicationRecord
  belongs_to :user
  has_many :deck_words, dependent: :destroy
  has_many :words, through: :deck_words
  validates :name, presence: true
end

# app/models/word.rb
class Word < ApplicationRecord
  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy
  validates :representation, presence: true
  validates :part_of_speech, presence: true
end

# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :decks, dependent: :destroy

  def superuser?
    superuser
  end
end

# app/models/deck_word.rb (new model)
class DeckWord < ApplicationRecord
  belongs_to :deck
  belongs_to :word
  validates :deck_id, uniqueness: { scope: :word_id }
end
```

## Phase 3: Superuser Implementation

### 3.1 Database Seeds for Superuser
**File to Create**: `db/seeds.rb`

**Implementation**:
```ruby
# Create superuser in development with simple password
superuser = User.find_or_create_by(email: 'abaird@bairdsnet.net') do |user|
  user.password = Rails.env.production? ? ENV['SUPERUSER_PASSWORD'] : 'secret!'
  user.superuser = true
end

puts "Superuser created: #{superuser.email}"
```

### 3.2 Google Secret Manager Integration
**Secret to Add**: `superuser-password`

**Production Deployment**:
- Add `SUPERUSER_PASSWORD` environment variable to Kubernetes secrets
- Update `k8s/secrets.yaml` to include superuser password from Google Secret Manager
- Update GitHub Actions to retrieve superuser password secret

**Development Handling**:
- Use hardcoded "secret!" password in development/test environments
- Document in `CLAUDE.md` that superuser password is "secret!" for local development

## Phase 4: Authorization with Pundit

### 4.1 Install and Configure Pundit
**Gemfile Addition**:
```ruby
gem 'pundit'
```

**Application Controller Update**:
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email])
  end
end
```

### 4.2 Create Pundit Policies
**Files to Create**:
- `app/policies/application_policy.rb`
- `app/policies/deck_policy.rb`
- `app/policies/word_policy.rb`
- `app/policies/gloss_policy.rb`

**Permission Matrix**:
- **Superuser**: Full access to all actions (decks, words, glosses)
- **Regular User**:
  - Decks: Full access (index, show, new, create, edit, update, destroy)
  - Words: Limited access (index, show only)
  - Glosses: Limited access (index, show only)

**Policy Implementations**:
```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user&.superuser?
  end

  def new?
    create?
  end

  def update?
    user&.superuser?
  end

  def edit?
    update?
  end

  def destroy?
    user&.superuser?
  end
end

# app/policies/deck_policy.rb
class DeckPolicy < ApplicationPolicy
  def create?
    user.present?  # All users can create decks
  end

  def update?
    user.present? && (user.superuser? || record.user == user)
  end

  def destroy?
    update?  # Same permissions as update
  end
end

# app/policies/word_policy.rb
class WordPolicy < ApplicationPolicy
  # Inherits from ApplicationPolicy
  # Regular users: index, show only
  # Superusers: all actions
end

# app/policies/gloss_policy.rb
class GlossPolicy < ApplicationPolicy
  # Inherits from ApplicationPolicy
  # Regular users: index, show only
  # Superusers: all actions
end
```

### 4.3 Update Controllers with Authorization
**Files to Modify**:
- `app/controllers/decks_controller.rb`
- `app/controllers/words_controller.rb`
- `app/controllers/glosses_controller.rb`

**Authorization Calls**:
```ruby
# Add to each controller action:
authorize @deck  # or @word, @gloss
authorize Deck   # for index actions
```

## Phase 5: Enhanced Form UI with Dropdowns (NEW)

### 5.1 Word Form Updates
**File to Modify**: `app/views/words/_form.html.erb`

**Goal**: Replace deck_id input with deck selection dropdown

**Implementation**:
```erb
<!-- Instead of deck_id field -->
<div class="field">
  <%= form.label :deck_ids, "Select Decks:" %>
  <%= form.collection_check_boxes :deck_ids,
      current_user.superuser? ? Deck.all : current_user.decks,
      :id, :name do |b| %>
    <div class="checkbox-item">
      <%= b.check_box %>
      <%= b.label %>
    </div>
  <% end %>
</div>
```

**Controller Updates**:
```ruby
# app/controllers/words_controller.rb
private

def word_params
  params.require(:word).permit(:representation, :part_of_speech, :mnemonic,
                               :pronunciation_url, :picture_url, deck_ids: [])
end
```

### 5.2 Gloss Form Updates
**File to Modify**: `app/views/glosses/_form.html.erb`

**Goal**: Replace word_id input with word selection dropdown

**Implementation**:
```erb
<!-- Instead of word_id field -->
<div class="field">
  <%= form.label :word_id, "Select Word:" %>
  <%= form.collection_select :word_id, Word.all, :id, :representation,
      { prompt: "Choose a word..." },
      { class: "form-select" } %>
</div>
```

### 5.3 Form Styling Improvements
**Goal**: Apply consistent Tailwind CSS styling to all form elements

**Files to Update**:
- `app/views/words/_form.html.erb`
- `app/views/glosses/_form.html.erb`
- `app/views/decks/_form.html.erb`

**Styling Classes**:
- Form containers: `space-y-4`
- Input fields: `form-input w-full`
- Labels: `block text-sm font-medium text-gray-700`
- Select dropdowns: `form-select w-full`
- Checkboxes: `form-checkbox`
- Submit buttons: `btn btn-primary`

## Phase 6: UI/UX Improvements

### 6.1 Authentication Flow
**Root Route Behavior**:
- **Unauthenticated**: Redirect to sign-in page
- **Authenticated**: Show words index with proper navigation

**Implementation**:
```ruby
# app/controllers/application_controller.rb
before_action :authenticate_user!, except: [:show] # for health controller

# Update routes.rb if needed to handle auth redirects properly
```

### 6.2 Navigation Header
**File to Create/Update**: `app/views/layouts/application.html.erb`

**Features**:
- User email display in top-right corner
- Logout button
- Navigation links based on permissions:
  - **Superuser**: Links to Decks, Words, Glosses (all actions)
  - **Regular User**: Links to Decks (all), Words (index only), Glosses (index only)

**Implementation**:
```erb
<nav class="navbar">
  <% if user_signed_in? %>
    <div class="nav-links">
      <%= link_to "Decks", decks_path %>
      <%= link_to "Words", words_path %>
      <%= link_to "Glosses", glosses_path if current_user.superuser? %>
    </div>
    <div class="user-info">
      <span><%= current_user.email %></span>
      <% if current_user.superuser? %>
        <span class="badge">Admin</span>
      <% end %>
      <%= link_to "Logout", destroy_user_session_path, method: :delete %>
    </div>
  <% end %>
</nav>
```

### 6.3 Sign-in Page Styling
**File to Update**: `app/views/devise/sessions/new.html.erb`

**Improvements**:
- Apply Tailwind CSS styling for better visual appeal
- Add welcome message and branding
- Improve form layout and button styling
- Add responsive design considerations

## Phase 7: Testing Updates

### 7.1 Model Tests
**Files to Update**:
- `spec/models/user_spec.rb`
- `spec/models/deck_spec.rb`
- `spec/models/word_spec.rb`
- `spec/models/deck_word_spec.rb` (new)

**Test Coverage**:
- Many-to-many associations
- Superuser functionality
- Model validations
- Dependent destroy behavior

### 7.2 Policy Tests
**Files to Create**:
- `spec/policies/deck_policy_spec.rb`
- `spec/policies/word_policy_spec.rb`
- `spec/policies/gloss_policy_spec.rb`

**Test Scenarios**:
- Superuser permissions
- Regular user permissions
- Unauthorized access attempts

### 7.3 Controller Tests
**Files to Update**:
- Update existing controller tests to include authorization checks
- Test dropdown form submissions
- Test permission-based action restrictions
- Verify proper redirect behavior for unauthorized users

### 7.4 Form Integration Tests
**New Test Coverage**:
- Test word creation with multiple deck selection
- Test gloss creation with word dropdown selection
- Test form validation with dropdown selections

## Phase 8: Documentation and Deployment

### 8.1 Update CLAUDE.md
**Sections to Update**:
- Model relationship documentation
- Superuser setup instructions
- Development vs production secret handling
- Updated database schema information
- Form UI documentation

### 8.2 Kubernetes Secret Updates
**Files to Modify**:
- `k8s/secrets.yaml` (add superuser password)
- GitHub Actions workflow (retrieve superuser secret)

### 8.3 Database Seed Integration
**Deployment Steps**:
- Ensure `rails db:seed` runs in production deployment
- Update initialization scripts for development environment
- Document superuser credentials for different environments

## Updated Implementation Timeline

1. **Phase 1-2**: Database and Model Changes (1-2 hours) - *Simplified without data migration*
2. **Phase 3**: Superuser Implementation (1-2 hours)
3. **Phase 4**: Pundit Authorization (2-3 hours)
4. **Phase 5**: Enhanced Form UI with Dropdowns (2-3 hours) - *NEW*
5. **Phase 6**: UI/UX Improvements (2-3 hours)
6. **Phase 7**: Testing Updates (2-3 hours) - *Includes new form tests*
7. **Phase 8**: Documentation and Deployment (1 hour)

**Total Estimated Time**: 11-17 hours (unchanged due to simplified data migration offsetting new form work)

## Key Changes from Original Plan

### Simplified:
- **No Data Migration**: Can reset database completely since no important data exists
- **Faster Database Changes**: No complex migration scripts needed
- **Cleaner Implementation**: Fresh start with proper schema from the beginning

### Enhanced:
- **Better UX**: Dropdown/checkbox selectors instead of ID inputs
- **Multi-selection**: Words can be assigned to multiple decks during creation
- **Word Selection**: Glosses use dropdown to select associated word
- **Form Validation**: Proper validation for dropdown selections
- **Additional Testing**: Form integration tests for dropdown functionality

### UI Form Improvements:
- **Word Forms**: Multi-select checkboxes for deck assignment
- **Gloss Forms**: Dropdown word selection
- **Consistent Styling**: Tailwind CSS classes throughout
- **Better UX**: No more manual ID entry

## Risk Mitigation

1. **Authorization Bypass**: Thorough testing of Pundit policies
2. **Production Secrets**: Secure secret management via Google Secret Manager
3. **Development Workflow**: Maintain simple development setup with hardcoded passwords
4. **Form Validation**: Proper validation for all dropdown and checkbox selections

This plan provides a systematic approach to transforming the application architecture while implementing proper security controls and improving user experience with better form interfaces.