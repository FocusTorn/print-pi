#!/bin/bash

# doGit - Enhanced Git wrapper with automatic commit messages and smart operations
# Usage: doGit [command] [options]
# Examples: doGit commit, doGit push, doGit status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
GIT_DIR="/home/pi/3dp-mods"
AUTO_COMMIT_MESSAGE_PREFIX="Auto-commit:"
DRY_RUN=false

# Parse command line arguments for --dry-run
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Logging function for dry-run
log_dry_run() {
    echo -e "${PURPLE}[DRY-RUN]${NC} $1"
}

# Function to show help
show_help() {
    echo -e "${CYAN}doGit - Enhanced Git Wrapper${NC}"
    echo -e "${CYAN}============================${NC}"
    echo
    echo "Usage: doGit [command] [options]"
    echo
    echo "Commands:"
    echo "  status     - Show git status with colors"
    echo "  add        - Add all changes to staging"
    echo "  commit     - Auto-commit with timestamp"
    echo "  commit-msg - Commit with custom message"
    echo "  push       - Push to remote repository"
    echo "  pull       - Pull from remote repository"
    echo "  log        - Show recent commit history"
    echo "  diff       - Show staged changes"
    echo "  reset      - Reset last commit (soft)"
    echo "  sync       - Add, commit, and push all changes"
    echo "  init       - Initialize git repository in 3dp-mods"
    echo "  help       - Show this help message"
    echo
    echo "Options:"
    echo "  --dry-run  - Show what would be executed without making changes"
    echo
    echo "Examples:"
    echo "  doGit status"
    echo "  doGit commit --dry-run"
    echo "  doGit commit"
    echo "  doGit commit-msg 'Fixed printer configuration'"
    echo "  doGit sync --dry-run"
}

# Function to check if we're in a git repository
check_git_repo() {
    if [ ! -d "$GIT_DIR/.git" ]; then
        echo -e "${RED}[ERROR]${NC} Not a git repository. Run 'doGit init' first."
        exit 1
    fi
}

# Function to get files that git will modify (for permission elevation)
get_git_target_files() {
    check_git_repo
    cd "$GIT_DIR"
    
    local files=()
    
    # Get modified files
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            files+=("$file")
        fi
    done < <(git diff --name-only 2>/dev/null)
    
    # Get untracked files
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            files+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard 2>/dev/null)
    
    # Get deleted files (for git add -A)
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            files+=("$file")
        fi
    done < <(git diff --name-only --diff-filter=D 2>/dev/null)
    
    # Add .git directory and index for git operations
    files+=(".git")
    files+=(".git/index")
    
    # Remove duplicates and return
    printf '%s\n' "${files[@]}" | sort -u
}

# Function to elevate permissions for specific files
elevate_file_permissions() {
    local files=("$@")
    
    if [ ${#files[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${CYAN}[INFO]${NC} Elevating permissions for git target files..."
    
    for file in "${files[@]}"; do
        if [ -e "$file" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_dry_run "Would elevate permissions for: $file"
            else
                # Make sure we can read/write the file/directory
                chmod u+rw "$file" 2>/dev/null
                # If it's a directory, also make it executable
                if [ -d "$file" ]; then
                    chmod u+x "$file" 2>/dev/null
                fi
            fi
        fi
    done
}

# Function to show git status with colors
show_status() {
    check_git_repo
    cd "$GIT_DIR"
    
    echo -e "${BLUE}Git Status for 3dp-mods:${NC}"
    echo -e "${BLUE}========================${NC}"
    
    # Show current branch
    local branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        echo -e "${GREEN}Current branch:${NC} $branch"
    else
        echo -e "${RED}No active branch${NC}"
    fi
    
    echo
    
    # Show status with colors
    git status --porcelain 2>/dev/null | while read -r line; do
        local status=${line:0:2}
        local file=${line:3}
        
        case "$status" in
            " M") echo -e "${YELLOW}Modified:${NC} $file" ;;
            "M ") echo -e "${GREEN}Staged:${NC} $file" ;;
            "??") echo -e "${PURPLE}Untracked:${NC} $file" ;;
            "A ") echo -e "${GREEN}Added:${NC} $file" ;;
            "D ") echo -e "${RED}Deleted:${NC} $file" ;;
            " D") echo -e "${RED}Deleted (unstaged):${NC} $file" ;;
            *) echo -e "${CYAN}$status:${NC} $file" ;;
        esac
    done
    
    echo
    echo -e "${BLUE}Summary:${NC}"
    git status --short 2>/dev/null | wc -l | xargs -I {} echo "Total changes: {}"
}

# Function to add all changes
add_all() {
    check_git_repo
    cd "$GIT_DIR"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} DRY-RUN: Would add all changes..."
        log_dry_run "Would execute: git add -A"
        local staged_count=$(git diff --cached --name-only | wc -l)
        local unstaged_count=$(git diff --name-only | wc -l)
        local untracked_count=$(git ls-files --others --exclude-standard | wc -l)
        log_dry_run "Would add $unstaged_count modified files and $untracked_count untracked files"
        log_dry_run "Total files that would be staged: $((unstaged_count + untracked_count))"
        
        # Show which files would be elevated
        local target_files=($(get_git_target_files))
        if [ ${#target_files[@]} -gt 0 ]; then
            log_dry_run "Files that would need permission elevation:"
            for file in "${target_files[@]}"; do
                log_dry_run "  - $file"
            done
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} Adding all changes..."
        
        # Get files that need permission elevation
        local target_files=($(get_git_target_files))
        elevate_file_permissions "${target_files[@]}"
        
        git add -A
        
        local staged_count=$(git diff --cached --name-only | wc -l)
        echo -e "${GREEN}[SUCCESS]${NC} Added $staged_count files to staging area"
    fi
}

# Function to auto-commit
auto_commit() {
    check_git_repo
    cd "$GIT_DIR"
    
    # Check if there are staged changes
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo -e "${YELLOW}[WARNING]${NC} No staged changes. Adding all changes first..."
        
        # Get files that need permission elevation before adding
        local target_files=($(get_git_target_files))
        elevate_file_permissions "${target_files[@]}"
        
        git add -A
        
        if [ -z "$(git diff --cached --name-only)" ]; then
            echo -e "${YELLOW}[INFO]${NC} No changes to commit"
            return 0
        fi
    fi
    
    # Generate commit message with timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local commit_msg="$AUTO_COMMIT_MESSAGE_PREFIX $timestamp"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} DRY-RUN: Would commit changes..."
        log_dry_run "Would execute: git commit -m '$commit_msg'"
        local staged_files=$(git diff --cached --name-only)
        if [ -n "$staged_files" ]; then
            log_dry_run "Files that would be committed:"
            echo "$staged_files" | while read -r file; do
                log_dry_run "  - $file"
            done
        fi
        log_dry_run "Commit message: $commit_msg"
    else
        echo -e "${YELLOW}[INFO]${NC} Committing changes..."
        git commit -m "$commit_msg"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[SUCCESS]${NC} Committed: $commit_msg"
        else
            echo -e "${RED}[ERROR]${NC} Commit failed"
            exit 1
        fi
    fi
}

# Function to commit with custom message
commit_with_message() {
    local message="$1"
    
    if [ -z "$message" ]; then
        echo -e "${RED}[ERROR]${NC} Please provide a commit message"
        echo "Usage: doGit commit-msg 'Your message here'"
        exit 1
    fi
    
    check_git_repo
    cd "$GIT_DIR"
    
    # Check if there are staged changes
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo -e "${YELLOW}[WARNING]${NC} No staged changes. Adding all changes first..."
        
        # Get files that need permission elevation before adding
        local target_files=($(get_git_target_files))
        elevate_file_permissions "${target_files[@]}"
        
        git add -A
        
        if [ -z "$(git diff --cached --name-only)" ]; then
            echo -e "${YELLOW}[INFO]${NC} No changes to commit"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}[INFO]${NC} Committing with message: '$message'"
    git commit -m "$message"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Committed: $message"
    else
        echo -e "${RED}[ERROR]${NC} Commit failed"
        exit 1
    fi
}

# Function to push changes
push_changes() {
    check_git_repo
    cd "$GIT_DIR"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} DRY-RUN: Would push changes to remote..."
        log_dry_run "Would execute: git push"
        local ahead_count=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$ahead_count" -gt 0 ]; then
            log_dry_run "Would push $ahead_count commits to remote"
            log_dry_run "Commits that would be pushed:"
            git log --oneline @{u}..HEAD 2>/dev/null | while read -r commit; do
                log_dry_run "  - $commit"
            done
        else
            log_dry_run "No commits to push (up to date with remote)"
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} Pushing changes to remote..."
        git push
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[SUCCESS]${NC} Changes pushed successfully"
        else
            echo -e "${RED}[ERROR]${NC} Push failed"
            exit 1
        fi
    fi
}

# Function to pull changes
pull_changes() {
    check_git_repo
    cd "$GIT_DIR"
    
    echo -e "${YELLOW}[INFO]${NC} Pulling changes from remote..."
    git pull
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Changes pulled successfully"
    else
        echo -e "${RED}[ERROR]${NC} Pull failed"
        exit 1
    fi
}

# Function to show recent log
show_log() {
    check_git_repo
    cd "$GIT_DIR"
    
    echo -e "${BLUE}Recent Commits:${NC}"
    echo -e "${BLUE}==============${NC}"
    git log --oneline -10 --graph --decorate --color=always
}

# Function to show diff
show_diff() {
    check_git_repo
    cd "$GIT_DIR"
    
    echo -e "${BLUE}Staged Changes:${NC}"
    echo -e "${BLUE}===============${NC}"
    git diff --cached --color=always
}

# Function to reset last commit
reset_last() {
    check_git_repo
    cd "$GIT_DIR"
    
    echo -e "${YELLOW}[WARNING]${NC} This will reset the last commit (soft reset)"
    echo -e "${YELLOW}[INFO]${NC} Changes will remain staged"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git reset --soft HEAD~1
        echo -e "${GREEN}[SUCCESS]${NC} Last commit reset. Changes remain staged."
    else
        echo -e "${YELLOW}[INFO]${NC} Reset cancelled"
    fi
}

# Function to sync (add, commit, push)
sync_all() {
    echo -e "${CYAN}[INFO]${NC} Starting sync operation..."
    
    # For sync, we need to ensure we have access to all git files upfront
    if [ "$DRY_RUN" = false ]; then
        echo -e "${CYAN}[INFO]${NC} Preparing git repository access..."
        local target_files=($(get_git_target_files))
        elevate_file_permissions "${target_files[@]}"
    fi
    
    add_all
    echo
    auto_commit
    echo
    push_changes
    
    echo -e "${GREEN}[SUCCESS]${NC} Sync completed successfully!"
}

# Function to initialize git repository
init_repo() {
    if [ -d "$GIT_DIR/.git" ]; then
        echo -e "${YELLOW}[WARNING]${NC} Git repository already exists in $GIT_DIR"
        return 0
    fi
    
    cd "$GIT_DIR"
    
    echo -e "${YELLOW}[INFO]${NC} Initializing git repository..."
    git init
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} Git repository initialized"
        
        # Create .gitignore if it doesn't exist
        if [ ! -f ".gitignore" ]; then
            cat > .gitignore << EOF
# Logs
*.log

# Temporary files
*.tmp
*.temp

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo
*~
EOF
            echo -e "${GREEN}[SUCCESS]${NC} Created .gitignore file"
        fi
        
        # Add initial commit
        git add .
        git commit -m "Initial commit: 3D printer modifications setup"
        
        echo -e "${GREEN}[SUCCESS]${NC} Initial commit created"
        echo -e "${YELLOW}[INFO]${NC} You may want to add a remote repository:"
        echo "  git remote add origin <your-repo-url>"
    else
        echo -e "${RED}[ERROR]${NC} Failed to initialize git repository"
        exit 1
    fi
}

# Main script logic
case "$1" in
    "status")
        show_status
        ;;
    "add")
        add_all
        ;;
    "commit")
        auto_commit
        ;;
    "commit-msg")
        commit_with_message "$2"
        ;;
    "push")
        push_changes
        ;;
    "pull")
        pull_changes
        ;;
    "log")
        show_log
        ;;
    "diff")
        show_diff
        ;;
    "reset")
        reset_last
        ;;
    "sync")
        sync_all
        ;;
    "init")
        init_repo
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown command: $1"
        echo "Run 'doGit help' for usage information"
        exit 1
        ;;
esac
