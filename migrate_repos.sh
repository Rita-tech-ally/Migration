#!/bin/bash

# ==========================================
# Bulk GitLab to GitHub Migration Tool
# ==========================================

GITLAB_TOKEN="Token"
GITHUB_TOKEN="token"
GITLAB_NAMESPACE="RitaDogra" 
GITHUB_USER="Rita-tech-ally"

# Define your repositories here in the format: "GitLab_Project_ID:Repository_Name"
REPOS=(
  "88010015:my-new-repo"
  "88010416:my-new-repo1"
  "88016211:devops"
)

# ==========================================

echo " Starting Bulk Migration from GitLab to GitHub..."

for repo_data in "${REPOS[@]}"; do
    # Extract Project ID and Repo Name
    GITLAB_PROJECT_ID="${repo_data%%:*}"
    REPO_NAME="${repo_data##*:}"
    
    GITLAB_REPO_URL="https://oauth2:${GITLAB_TOKEN}@gitlab.com/${GITLAB_NAMESPACE}/${REPO_NAME}.git"
    GITHUB_REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

    echo "---------------------------------------------------"
    echo " Processing Repository: $REPO_NAME (GitLab ID: $GITLAB_PROJECT_ID)"
    
    # Step 1: Clone bare repository
    echo " Cloning GitLab repository..."
    git clone --bare "$GITLAB_REPO_URL" "${REPO_NAME}_migration.git"
    cd "${REPO_NAME}_migration.git" || { echo " Failed to clone $REPO_NAME"; continue; }

    # Step 2: Create a new private repository on GitHub
    echo " Creating repository on GitHub..."
    curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         -d '{"name":"'"$REPO_NAME"'", "private":true}' \
         "https://api.github.com/user/repos" > /dev/null

    # Step 3: Push everything to GitHub
    echo " Pushing all branches, tags, and commits to GitHub..."
    git push --mirror "$GITHUB_REPO_URL"

    # Step 4: Migrate Webhooks
    echo " Fetching webhooks from GitLab..."
    WEBHOOKS=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID/hooks")

    echo "$WEBHOOKS" | /usr/local/bin/jq -c '.[]' | while read -r hook; do
        HOOK_URL=$(echo "$hook" | /usr/local/bin/jq -r '.url')

        if [ "$HOOK_URL" != "null" ] && [ -n "$HOOK_URL" ]; then
            echo " Migrating webhook: $HOOK_URL..."
            
            curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3+json" \
                 "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/hooks" \
                 -d '{
                       "name": "web",
                       "active": true,
                       "events": ["push", "pull_request"],
                       "config": {
                         "url": "'"$HOOK_URL"'",
                         "content_type": "json",
                         "insecure_ssl": "0"
                       }
                     }' > /dev/null
        fi
    done

    # Clean up local bare clone
    cd ..
    rm -rf "${REPO_NAME}_migration.git"
    
    echo " Completed: $REPO_NAME"
done

echo "---------------------------------------------------"
echo " All Repositories Migrated Successfully!"
