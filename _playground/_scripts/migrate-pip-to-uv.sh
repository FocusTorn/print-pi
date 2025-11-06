#!/bin/bash
# Migrate pip-installed packages to uv
# Moves packages from pip-installed venvs to uv-managed venvs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAKE_PIT_DIR="${HOME}/_playground/snake-pit"

echo "🔄 Migrating pip-installed packages to uv..."
echo ""

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "❌ uv not found. Please install uv first:"
    echo "   ${HOME}/_playground/_scripts/bootstraps/bootstrap-snake-pit.sh"
    exit 1
fi

echo "✅ uv found: $(uv --version)"
echo ""

# 1. Create/ensure snake-pit venv exists
echo "📦 Setting up snake-pit/.venv..."
cd "$SNAKE_PIT_DIR"

if [ ! -d ".venv" ]; then
    echo "   Creating snake-pit virtual environment..."
    uv venv
    echo "   ✅ Created .venv"
else
    echo "   ✅ .venv already exists"
fi

# Install snake-pit requirements
if [ -f "requirements.txt" ]; then
    echo "   Installing snake-pit requirements..."
    uv pip install -r requirements.txt --python .venv/bin/python
    echo "   ✅ snake-pit requirements installed"
fi

# 2. Migrate bme680-service venv
echo ""
echo "📦 Migrating bme680-service/.venv..."
BME680_VENV="${HOME}/.local/share/bme680-service/.venv"
BME680_REQ="${HOME}/_playground/_dev/packages/bme680-service/data/requirements.txt"

if [ -d "$BME680_VENV" ]; then
    echo "   Current packages:"
    if [ -f "$BME680_VENV/bin/pip" ]; then
        "$BME680_VENV/bin/pip" list 2>/dev/null | tail -n +3 | sed 's/^/     /'
    fi
    
    # Check if venv was created with uv
    if [ ! -f "$BME680_VENV/pyvenv.cfg" ] || ! grep -q "uv" "$BME680_VENV/pyvenv.cfg" 2>/dev/null; then
        echo "   ⚠️  venv was created with pip, recreating with uv..."
        echo "   Backing up current venv..."
        mv "$BME680_VENV" "${BME680_VENV}.pip-backup"
        
        echo "   Creating new venv with uv..."
        uv venv "$BME680_VENV"
        
        echo "   Installing requirements..."
        if [ -f "$BME680_REQ" ]; then
            uv pip install -r "$BME680_REQ" --python "$BME680_VENV/bin/python"
        fi
        
        echo "   ✅ bme680-service venv migrated to uv"
        echo "   📝 Old venv backed up to: ${BME680_VENV}.pip-backup"
    else
        echo "   ✅ Already using uv"
    fi
else
    echo "   ⚠️  venv not found, skipping"
fi

# 3. Migrate pi-to-ha-reporter venv
echo ""
echo "📦 Migrating pi-to-ha-reporter/.venv..."
PIHA_VENV="${HOME}/.local/share/pi-to-ha-reporter/.venv"
PIHA_REQ="${HOME}/_playground/_dev/packages/pi-to-ha-reporter/data/requirements.txt"

if [ -d "$PIHA_VENV" ]; then
    echo "   Current packages:"
    if [ -f "$PIHA_VENV/bin/pip" ]; then
        "$PIHA_VENV/bin/pip" list 2>/dev/null | tail -n +3 | sed 's/^/     /'
    fi
    
    # Check if venv was created with uv
    if [ ! -f "$PIHA_VENV/pyvenv.cfg" ] || ! grep -q "uv" "$PIHA_VENV/pyvenv.cfg" 2>/dev/null; then
        echo "   ⚠️  venv was created with pip, recreating with uv..."
        echo "   Backing up current venv..."
        mv "$PIHA_VENV" "${PIHA_VENV}.pip-backup"
        
        echo "   Creating new venv with uv..."
        uv venv "$PIHA_VENV"
        
        echo "   Installing requirements..."
        if [ -f "$PIHA_REQ" ]; then
            uv pip install -r "$PIHA_REQ" --python "$PIHA_VENV/bin/python"
        fi
        
        echo "   ✅ pi-to-ha-reporter venv migrated to uv"
        echo "   📝 Old venv backed up to: ${PIHA_VENV}.pip-backup"
    else
        echo "   ✅ Already using uv"
    fi
else
    echo "   ⚠️  venv not found, skipping"
fi

# 4. Summary
echo ""
echo "✅ Migration complete!"
echo ""
echo "📊 Summary:"
echo "   • snake-pit/.venv: Shared packages from requirements.txt"
echo "   • bme680-service/.venv: Service-specific packages"
echo "   • pi-to-ha-reporter/.venv: Service-specific packages"
echo ""
echo "🗑️  Old pip venvs backed up with .pip-backup suffix"
echo "   (You can remove them after verifying services work)"
echo ""
echo "📝 To add shared packages to snake-pit:"
echo "   cd ${SNAKE_PIT_DIR}"
echo "   uv pip install <package> --python .venv/bin/python"
echo "   uv pip freeze > requirements.txt"
