# Script Name: Multi-GitLab to Single GitHub Bulk Migration Tool

# Description: Migrates repositories from multiple GitLab accounts into one

#              single GitHub account, including commit history and webhooks.

# ==============================================================================



# --- Global GitHub Configuration ---

GITHUB_TOKEN="github_token"

GITHUB_USER="Rita-tech-ally"



# --- Repositories Configuration ---

# Format: "GITLAB_TOKEN|GITLAB_NAMESPACE|GITLAB_PROJECT_ID|REPO_NAME"

REPOS=(

    "glpat-dHolMau3KA6oWUwVV2zbfGM6MQpvOjEKdTpxMDBkdA8.01.171svkj3z|RitaDogra|88010015|my-new-repo"

    "glpat-JYxXUoO6a0M18e4c661j1GM6MQpvOjEKdTpxMTVvOQ8.01.171mge7pn|opstree-group1732943|88075942|myproject"

)





# --- Dependency Check ---

for cmd in git curl jq; do

    if ! command -v $cmd &> /dev/null; then

        echo "[ERROR] Required command '$cmd' is not installed. Please install it before running."

        exit 1

    fi

done



echo "[INFO] Starting Multi-Account Migration from GitLab to GitHub..."



for repo_data in "${REPOS[@]}"; do

    IFS='|' read -r GL_TOKEN GL_NAMESPACE GL_PROJ_ID REPO_NAME <<< "$repo_data"

    

    GITLAB_REPO_URL="https://oauth2:${GL_TOKEN}@gitlab.com/${GL_NAMESPACE}/${REPO_NAME}.git"

    GITHUB_REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"



    echo "--------------------------------------------------------------------------------"

    echo "[INFO] Processing Repository: $REPO_NAME (GitLab Namespace: $GL_NAMESPACE)"

    

    # Step 1: Clone bare repository

    echo "[INFO] Cloning GitLab repository..."

    if ! git clone --bare "$GITLAB_REPO_URL" "${REPO_NAME}_migration.git"; then

        echo "[ERROR] Failed to clone $REPO_NAME. Skipping to next repository..."

        continue

    fi



    cd "${REPO_NAME}_migration.git" || exit 1



    # Step 2: Create a new private repository on GitHub

    echo "[INFO] Creating repository on GitHub..."

    curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \

         -H "Accept: application/vnd.github.v3+json" \

         -d '{"name":"'"$REPO_NAME"'", "private":true}' \

         "https://api.github.com/user/repos" > /dev/null



    # Step 3: Push everything to GitHub

    echo "[INFO] Pushing all branches, tags, and commits to GitHub..."

    if ! git push --mirror "$GITHUB_REPO_URL"; then

        echo "[ERROR] Failed to push $REPO_NAME to GitHub."

    fi



    # Step 4: Migrate Webhooks

    echo "[INFO] Fetching webhooks from GitLab..."

    WEBHOOKS=$(curl -s -H "PRIVATE-TOKEN: $GL_TOKEN" "https://gitlab.com/api/v4/projects/$GL_PROJ_ID/hooks")



    echo "$WEBHOOKS" | jq -c '.[]?' 2>/dev/null | while read -r hook; do

        HOOK_URL=$(echo "$hook" | jq -r '.url')



        if [ "$HOOK_URL" != "null" ] && [ -n "$HOOK_URL" ]; then

            echo "[INFO] Migrating webhook: $HOOK_URL..."

            

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

    

    echo "[SUCCESS] Completed: $REPO_NAME"

done



echo "--------------------------------------------------------------------------------"

echo "[SUCCESS] All Repositories Migrated Successfully!"
