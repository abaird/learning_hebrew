# Use Active Record session store for persistent sessions across app restarts
Rails.application.config.session_store :active_record_store, key: "_learning_hebrew_session"
