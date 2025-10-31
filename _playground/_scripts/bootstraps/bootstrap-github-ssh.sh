#!/usr/bin/env bash
# Bootstrap GitHub SSH authentication setup for system restore
# Creates SSH key for GitHub authentication and configures Git to use SSH

set -e

SSH_KEY_PATH="$HOME/.ssh/github_pi"
SSH_CONFIG="$HOME/.ssh/config"
GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo 'user@example.com')}"

echo "🔑 Bootstrapping GitHub SSH authentication..."

# Check if SSH key already exists
if [ -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key already exists at $SSH_KEY_PATH"
    read -p "Recreate SSH key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "ℹ️  Skipping SSH key generation"
    else
        echo "🗑️  Removing existing key..."
        rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
    fi
fi

# Generate SSH key if it doesn't exist
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "🔐 Generating SSH key pair..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY_PATH" -N ""
    echo "✅ SSH key created: $SSH_KEY_PATH"
else
    echo "✅ Using existing SSH key"
fi

# Configure SSH to use the key for GitHub
echo "⚙️  Configuring SSH for GitHub..."
mkdir -p "$HOME/.ssh"

# Check if GitHub config already exists
if grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo "⚠️  GitHub SSH config already exists in $SSH_CONFIG"
    read -p "Update configuration? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove existing GitHub config block
        sed -i '/^Host github\.com$/,/^$/d' "$SSH_CONFIG"
        echo "🗑️  Removed existing GitHub configuration"
    else
        echo "ℹ️  Keeping existing SSH config"
    fi
fi

# Add GitHub SSH config if not present
if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    cat >> "$SSH_CONFIG" << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_pi
    IdentitiesOnly yes

EOF
    echo "✅ SSH config updated"
fi

chmod 600 "$SSH_CONFIG"

# Display public key
echo ""
echo "📋 Your public SSH key:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$SSH_KEY_PATH.pub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Update Git remotes to use SSH (if in a git repo)
if git rev-parse --git-dir &> /dev/null; then
    CURRENT_DIR=$(pwd)
    echo "📂 Detected Git repository at: $CURRENT_DIR"
    
    # Fix non-standard remote name (Cursor expects 'origin')
    if git remote | grep -q "^main$" && ! git remote | grep -q "^origin$"; then
        echo "⚠️  Remote named 'main' detected (non-standard)"
        echo "🔧 Renaming remote 'main' → 'origin' (for Cursor compatibility)"
        git remote rename main origin
    fi
    
    # Get all remotes
    REMOTES=$(git remote)
    
    if [ -n "$REMOTES" ]; then
        echo "🔄 Updating Git remotes to use SSH..."
        
        for REMOTE in $REMOTES; do
            URL=$(git remote get-url "$REMOTE")
            
            # Convert HTTPS GitHub URLs to SSH
            if [[ "$URL" =~ https://github\.com/(.+)/(.+)(\.git)?$ ]]; then
                USER="${BASH_REMATCH[1]}"
                REPO="${BASH_REMATCH[2]%.git}"  # Remove .git if present
                NEW_URL="git@github.com:$USER/$REPO.git"
                
                echo "  📝 $REMOTE: $URL → $NEW_URL"
                git remote set-url "$REMOTE" "$NEW_URL"
            else
                echo "  ℹ️  $REMOTE: $URL (not a GitHub HTTPS URL, skipping)"
            fi
        done
        
        echo "✅ Git remotes updated"
        echo ""
        git remote -v
        
        # Set origin/HEAD for Cursor compatibility
        if git remote | grep -q "^origin$"; then
            DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's|^origin/||')
            if [ -z "$DEFAULT_BRANCH" ]; then
                # Try to detect default branch
                DEFAULT_BRANCH=$(git branch -r | grep "origin/HEAD" | sed 's|.*origin/||' || echo "main")
                if [ "$DEFAULT_BRANCH" = "main" ] || [ "$DEFAULT_BRANCH" = "master" ]; then
                    echo "🔧 Setting origin/HEAD to origin/$DEFAULT_BRANCH"
                    git remote set-head origin "$DEFAULT_BRANCH" 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/main"
                fi
            fi
        fi
    fi
    
    # Fix SSH key permissions
    echo "🔒 Fixing SSH key permissions..."
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"
fi

# Configure Cursor git.path if workspace file exists
WORKSPACE_FILE="$HOME/.vscode/RPi-Full.code-workspace"
if [ -f "$WORKSPACE_FILE" ]; then
    echo "⚙️  Configuring Cursor git path..."
    if ! grep -q '"git.path"' "$WORKSPACE_FILE"; then
        # Add git.path to workspace settings
        sed -i '/"git.enabled":/i\    "git.path": "/usr/bin/git",' "$WORKSPACE_FILE"
        echo "✅ Added git.path to workspace settings"
    else
        echo "ℹ️  git.path already configured in workspace"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GitHub SSH setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo "   1. Go to: https://github.com/settings/keys"
echo "   2. Click 'New SSH key'"
echo "   3. Title: 'Pi (github_pi)'"
echo "   4. Key type: 'Authentication Key'"
echo "   5. Paste the public key shown above"
echo "   6. Click 'Add SSH key'"
echo ""
echo "🧪 Test your connection:"
echo "   ssh -T git@github.com"
echo ""
echo "🚀 Push to GitHub:"
echo "   git push origin main"
echo ""
echo "⚠️  Cursor Setup:"
echo "   - Restart Cursor after running this script"
echo "   - Sign in to GitHub: Ctrl+Shift+P → 'GitHub: Sign In'"
echo "   - This enables Background Agents and git integration"
echo ""
echo "💡 Note: Git remotes should be named 'origin' (standard convention)"
echo "   If you have a remote named 'main', rename it:"
echo "   git remote rename main origin"
echo ""




