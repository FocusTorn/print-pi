# Chamon TUI

A Rust-based Terminal User Interface for system monitoring on Raspberry Pi.

## Installation

### Quick Install

```bash
bash install.sh
```

The install script will:
1. ✅ Check for Rust/Cargo dependencies
2. 🔨 Build chamon (you choose dev or prod)
3. 📦 Install smart wrapper to `~/.local/bin/chamon`
4. ✓ Verify installation

### Requirements

- **Rust & Cargo**: Required for compilation
  - Install via bootstrap: `bash /home/pi/_playground/_scripts/bootstraps/bootstrap-rust.sh`
  - Or manually: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

## Usage

Once installed:

```bash
chamon          # Launch the TUI
```

## Development

### Build Types

**Development Build (Fast)**
```bash
cargo build
# Binary: target/debug/chamon
```

**Production Build (Optimized)**
```bash
cargo build --release
# Binary: target/release/chamon
```

### Smart Wrapper

The installed wrapper at `~/.local/bin/chamon` automatically:
- Detects which builds exist (dev/prod)
- Uses the newer build if both exist
- Falls back to whichever exists if only one is present

This means you can freely rebuild during development and the wrapper will always use your latest build! 🎯

### Project Structure

```
chamon/
├── src/
│   ├── main.rs          # Entry point
│   └── lib.rs           # Library exports
├── lib/
│   └── common.sh        # Shared bash functions
├── system-monitor       # CLI tool (bash)
├── system-tracker       # CLI tool (bash)
├── Cargo.toml
└── install.sh           # Installation script
```

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed design documentation.

## Troubleshooting

**Wrapper says "No chamon binary found!"**
```bash
# Build it first
cargo build
# or
cargo build --release
```

**Command not found: chamon**
```bash
# Make sure ~/.local/bin is in your PATH
export PATH="$HOME/.local/bin:$PATH"

# Add to ~/.zshrc or ~/.bashrc to make permanent
```

**Cargo not found**
```bash
# Install Rust/Cargo
bash /home/pi/_playground/_scripts/bootstraps/bootstrap-rust.sh

# Then source the environment
source ~/.cargo/env
```

## Notes

- The wrapper checks timestamps to use the most recent build
- You can have both dev and prod builds simultaneously
- Rebuilding automatically updates which binary is used
- No need to reinstall after rebuilding! 🚀

