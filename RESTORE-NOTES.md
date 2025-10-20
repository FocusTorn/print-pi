# System Restore Notes

## Oh-My-Zsh Restoration Strategy

### Why OMZ Is Not Fully Tracked

This repo does NOT track the entire Oh-My-Zsh installation (~4MB of framework code, git history, and contributor docs). Instead, we use a **symlink strategy**:

**✅ What IS tracked:**
- `_playground/zsh/custom/` - Your custom plugins, themes, and functions (REAL files)
- `.zshrc` - Your zsh configuration (specifies which plugins/themes to use)
- `_playground/_scripts/bootstrap-omz.sh` - Installation script

**❌ What is NOT tracked:**
- `.oh-my-zsh/` - The entire OMZ directory (ignored)
- The OMZ framework itself (can be re-downloaded)
- OMZ `.git` repository (~3.7M of history)
- OMZ `.github/` directory (CI workflows)
- Contributor documentation (CODE_OF_CONDUCT, CONTRIBUTING, etc.)

**🔗 How Symlinks Work:**
- Real files live in: `_playground/zsh/custom/` (version controlled)
- OMZ uses them via: `.oh-my-zsh/custom` → `_playground/zsh/custom/` (symlink)
- This way your configs are tracked, but OMZ framework is not!

### Restoration Process

1. **Clone this repo** to `/home/pi`
2. **Run the bootstrap script:**
   ```bash
   bash _playground/_scripts/bootstrap-omz.sh
   ```
3. **Verify customizations** are loaded in `~/.oh-my-zsh/custom/`
4. **Restart your shell** or run `source ~/.zshrc`

### Why This Approach?

- **Smaller repo**: Your restore repo stays lean (only YOUR configs)
- **Always up-to-date**: Re-downloading OMZ gives you the latest stable version
- **Clean separation**: Framework vs. your customizations
- **No git conflicts**: OMZ won't auto-update and mess with your repo
- **Less noise**: No upstream project cruft polluting your commits

### Manual Alternative

If you don't want to use the bootstrap script:

```bash
# Install OMZ manually
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Clean up cruft (optional)
rm -rf ~/.oh-my-zsh/.git ~/.oh-my-zsh/.github
rm ~/.oh-my-zsh/{CODE_OF_CONDUCT,CONTRIBUTING,SECURITY,README}.md

# Your custom configs should already be in place from the repo
```

---

## Other Restoration Notes

*(Add your other system restore notes here)*

