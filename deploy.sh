#!/usr/bin/env bash
set -euo pipefail

#
#  deploy.sh
#
#  1) Rsync your Obsidian posts
#  2) Run images.py to fix image paths
#  3) Build Hugo
#  4) Commit & push changes to `main`
#  5) Split `public/` into a temp branch and force‐push to `gh-pages`
#

# ──────────────────────────────────────────────────────────
# 0) Move into this script’s directory so relative paths work
# ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ──────────────────────────────────────────────────────────
# 1) DEFINE PATHS & GIT REMOTE
# ──────────────────────────────────────────────────────────
#
# 1a) Change these paths to where your Obsidian "posts" live and
#     where your Hugo site is located. E.g.:
sourcePath="/Users/ianstewart/Chest/posts"
destinationPath="$SCRIPT_DIR/content/posts"

# 1b) FULL GitHub remote URL. Replace <YOUR_GITHUB_USERNAME> below:
myrepo="git@github.com:ghost1034/blog.git"

# ──────────────────────────────────────────────────────────
# 2) CHECK for required commands
# ──────────────────────────────────────────────────────────
for cmd in git rsync python3 hugo; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Required command '$cmd' not found in PATH."
        exit 1
    fi
done

# ──────────────────────────────────────────────────────────
# 3) INITIALIZE GIT (if needed) & add remote origin
# ──────────────────────────────────────────────────────────
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
    git remote add origin "$myrepo"
else
    echo "Git already initialized."
    if ! git remote | grep -q '^origin$'; then
        echo "Adding missing remote origin..."
        git remote add origin "$myrepo"
    fi
fi

# ──────────────────────────────────────────────────────────
# 4) SYNC Obsidian → Hugo `content/posts` via rsync
# ──────────────────────────────────────────────────────────
echo "🔄 Syncing posts from Obsidian..."
if [ ! -d "$sourcePath" ]; then
    echo "ERROR: Source path does not exist: $sourcePath"
    exit 1
fi
if [ ! -d "$destinationPath" ]; then
    echo "ERROR: Destination path does not exist: $destinationPath"
    exit 1
fi

rsync -av --delete "$sourcePath"/ "$destinationPath"/
# note the trailing slashes—this syncs just the contents of sourcePath
# into destinationPath.

# ──────────────────────────────────────────────────────────
# 5) RUN Python script to rewrite image links, etc.
# ──────────────────────────────────────────────────────────
echo "🖼️  Processing image links in Markdown..."
if [ ! -f "images.py" ]; then
    echo "ERROR: images.py not found in project root."
    exit 1
fi
python3 images.py

# ──────────────────────────────────────────────────────────
# 6) BUILD HUGO SITE
# ──────────────────────────────────────────────────────────
echo "🚧 Building Hugo site..."
hugo
# By default, Hugo writes to ./public/

# ──────────────────────────────────────────────────────────
# 7) STAGE & COMMIT any changes to main branch
# ──────────────────────────────────────────────────────────
echo "📥 Staging changes for Git..."
# Only add if there is something new/changed:
if git diff --quiet && git diff --cached --quiet; then
    echo "✅ No changes to stage on main."
else
    git add .
    commit_message="Update site content: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "💬 Committing to main: '$commit_message'"
    git commit -m "$commit_message"
fi

echo "🚀 Pushing to origin/main..."
git push origin HEAD:main

# ──────────────────────────────────────────────────────────
# 8) DEPLOY public/ → gh‑pages branch
# ──────────────────────────────────────────────────────────
#
# We create a temporary branch (gh-temp) containing ONLY the 
# contents of public/. Then force‐push that to origin/gh-pages.
#
echo "📂 Deploying public/ → gh‑pages branch..."

# If a previous temp branch exists, delete it
if git show-ref --quiet refs/heads/gh-temp; then
    git branch -D gh-temp
fi

# Create a subtree split called gh-temp containing only public/
git subtree split --prefix=public -b gh-temp

# Force‐push gh-temp to origin’s gh-pages branch
git push origin gh-temp:gh-pages --force

# Delete our local gh-temp branch
git branch -D gh-temp

echo "🎉 Deployment to GitHub Pages complete!"
echo "    - main → (source for future edits) @ origin/main"
echo "    - public subtree → (site) @ origin/gh-pages"
