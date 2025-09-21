# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hebrew learning application built with Ruby on Rails 8, featuring a hierarchical vocabulary structure:
- Users create multiple Decks (vocabulary collections)
- Each Deck contains Words (Hebrew vocabulary)
- Each Word has multiple Glosses (translations/definitions)

## Development Commands

### Local Development
```bash
# Start development server with CSS watch
bin/dev

# Start Rails server only
bin/rails server

# Start Rails console
bin/rails console

# Generate new migrations
bin/rails generate migration MigrationName

# Run database migrations
bin/rails db:migrate

# Reset database
bin/rails db:reset
```

### Docker Development
```bash
# Start services (PostgreSQL + Rails app)
docker-compose -f docker-compose.dev.yml up

# Run Rails commands in container
docker-compose -f docker-compose.dev.yml exec web bin/rails console
```

### Testing
```bash
# Run RSpec test suite
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

### Code Quality
```bash
# Run Rubocop linter
bundle exec rubocop

# Auto-fix Rubocop issues
bundle exec rubocop -A

# Run Brakeman security scanner
bundle exec brakeman
```

## Architecture

### Database Schema
- **users**: Devise authentication (email, password)
- **decks**: Named collections belonging to users (name, description, user_id)
- **words**: Hebrew vocabulary items (representation, part_of_speech, mnemonic, pronunciation_url, picture_url, deck_id)
- **glosses**: Translation definitions (text, word_id)

### Model Relationships
```
User (1) → Decks (many) → Words (many) → Glosses (many)
```

### Key Technologies
- **Rails 8.0** with modern defaults
- **PostgreSQL** database
- **Devise** for authentication
- **Tailwind CSS** for styling
- **Turbo/Stimulus** for frontend interactivity
- **RSpec** for testing
- **Docker** for containerized development

### File Structure
- `app/models/`: ActiveRecord models with validations and associations
- `app/controllers/`: RESTful controllers for decks, words, glosses
- `app/views/`: ERB templates organized by controller
- `db/migrate/`: Database migration files
- `config/routes.rb`: Defines RESTful routes for all resources

## Development Environment

The application supports both local and Docker development:

**Local**: Requires PostgreSQL, Ruby, and Node.js. Uses `bin/dev` to start Rails server and Tailwind CSS watcher.

**Docker**: Complete environment with PostgreSQL container. Database connection configured for container networking (host: `db`).

## Authentication

Uses Devise with standard email/password authentication. User registration and authentication routes are automatically generated.