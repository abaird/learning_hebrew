#!/bin/bash

# Script to toggle between local and production Docker images in k8s/rails-app.yaml

LOCAL_IMAGE="learning-hebrew:latest"
PROD_IMAGE="us-central1-docker.pkg.dev/learning-hebrew-1758491674/learning-hebrew/learning-hebrew:latest"
RAILS_APP_FILE="k8s/rails-app.yaml"

# Check current state - look for exact image match
if grep -q "image: $LOCAL_IMAGE" "$RAILS_APP_FILE"; then
    echo "🔄 Switching from LOCAL to PRODUCTION images..."
    sed -i.bak "s|image: $LOCAL_IMAGE|image: $PROD_IMAGE|g" "$RAILS_APP_FILE"
    echo "✅ Now using PRODUCTION images"
elif grep -q "us-central1-docker.pkg.dev" "$RAILS_APP_FILE"; then
    echo "🔄 Switching from PRODUCTION to LOCAL images..."
    # Replace any variation of the production image with local
    sed -i.bak "s|image: us-central1-docker\.pkg\.dev/learning-hebrew-1758491674/learning-hebrew/learning-hebrew:latest|image: $LOCAL_IMAGE|g" "$RAILS_APP_FILE"
    echo "✅ Now using LOCAL images"
else
    echo "❌ Could not detect current image type in $RAILS_APP_FILE"
    echo "Current image lines:"
    grep "image:" "$RAILS_APP_FILE" | grep -v "#"
    exit 1
fi

echo "📝 Backup saved as ${RAILS_APP_FILE}.bak"
echo "🔍 Current images in use:"
grep "image:" "$RAILS_APP_FILE" | grep -v "#"