#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# FlowPass - GitHub Release & Extension Packaging Helper
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Terminal formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

print_usage() {
  echo -e "${BOLD}FlowPass Release Helper${NC}

Usage:
  ./scripts/release.sh [OPTIONS] [VERSION]

Options:
  -d, --draft          Create the release as a draft (do not publish immediately)
  -p, --prerelease     Mark the release as a pre-release
  -n, --notes <text>   Custom release notes (if omitted, GitHub generates notes automatically)
  -y, --yes            Skip interactive confirmation prompts
  -h, --help           Show this help message

Examples:
  ./scripts/release.sh                 # Interactive mode (reads current or prompts version)
  ./scripts/release.sh 1.2.0           # Specify version 1.2.0
  ./scripts/release.sh v1.2.0 --draft  # Create v1.2.0 as a draft release
  ./scripts/release.sh --prerelease    # Pre-release"
}

# Defaults
TARGET_VERSION=""
IS_DRAFT=false
IS_PRERELEASE=false
CUSTOM_NOTES=""
AUTO_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    -d|--draft)
      IS_DRAFT=true
      shift
      ;;
    -p|--prerelease)
      IS_PRERELEASE=true
      shift
      ;;
    -n|--notes)
      if [[ -z "${2:-}" ]]; then
        log_error "Missing value for $1"
        exit 1
      fi
      CUSTOM_NOTES="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_CONFIRM=true
      shift
      ;;
    -*)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
    *)
      if [[ -z "$TARGET_VERSION" ]]; then
        TARGET_VERSION="$1"
      else
        log_error "Unexpected argument: $1"
        print_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Check required utilities
log_info "Verifying required tools..."
for cmd in git gh zip; do
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required tool '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

# Check GitHub auth
if ! gh auth status &>/dev/null; then
  log_error "You are not logged into GitHub CLI. Run 'gh auth login' first."
  exit 1
fi

# Fetch remote tags
log_info "Fetching latest remote tags and branches..."
git fetch origin --tags -q

# Read current version from manifest.json
MANIFEST_FILE="$REPO_ROOT/manifest.json"
if [[ ! -f "$MANIFEST_FILE" ]]; then
  log_error "manifest.json not found at $MANIFEST_FILE"
  exit 1
fi

CURRENT_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST_FILE" | head -n1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
if [[ -z "$CURRENT_VERSION" ]]; then
  log_error "Failed to parse version from manifest.json"
  exit 1
fi

# Determine target version
if [[ -z "$TARGET_VERSION" ]]; then
  if [[ "$AUTO_CONFIRM" == true ]]; then
    TARGET_VERSION="$CURRENT_VERSION"
  else
    echo -e "${CYAN}Current version in manifest.json:${NC} ${BOLD}$CURRENT_VERSION${NC}"
    read -r -p "Enter version to release [default: $CURRENT_VERSION]: " input_ver
    TARGET_VERSION="${input_ver:-$CURRENT_VERSION}"
  fi
fi

# Strip leading 'v'
TARGET_VERSION="${TARGET_VERSION#v}"

# Validate semantic version syntax (e.g. 1.0.0, 1.2.0-rc1)
if [[ ! "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  log_error "Invalid version format: '$TARGET_VERSION'. Expected semver (e.g., 1.2.0 or 1.2.0-beta.1)."
  exit 1
fi

TAG_NAME="v$TARGET_VERSION"
log_info "Target release: ${BOLD}$TAG_NAME${NC} (version: $TARGET_VERSION)"

# Check if tag or release already exists
if git rev-parse "$TAG_NAME" &>/dev/null || git ls-remote --tags origin "refs/tags/$TAG_NAME" | grep -q "$TAG_NAME"; then
  if gh release view "$TAG_NAME" &>/dev/null; then
    log_error "GitHub release for tag '$TAG_NAME' already exists! Aborting."
    exit 1
  else
    log_warn "Git tag '$TAG_NAME' exists locally or remotely, but no GitHub release was found."
  fi
fi

# If version is bumped, ensure working tree is clean before bumping
if [[ "$TARGET_VERSION" != "$CURRENT_VERSION" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    log_error "Working directory has uncommitted changes. Please commit or stash them before bumping version."
    git status -s
    exit 1
  fi

  log_info "Bumping version from $CURRENT_VERSION to $TARGET_VERSION in manifest.json..."
  
  if command -v jq &>/dev/null; then
    tmp_manifest=$(mktemp)
    jq --arg v "$TARGET_VERSION" '.version = $v' "$MANIFEST_FILE" > "$tmp_manifest"
    mv "$tmp_manifest" "$MANIFEST_FILE"
  else
    sed -i.bak -E "s/(\"version\"[[:space:]]*:[[:space:]]*)\"[^\"]*\"/\1\"$TARGET_VERSION\"/" "$MANIFEST_FILE"
    rm -f "${MANIFEST_FILE}.bak"
  fi

  git add "$MANIFEST_FILE"
  git commit -m "chore(release): bump version to $TARGET_VERSION"
  log_info "Pushing version bump to remote..."
  git push origin HEAD
fi

# Package extension
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="flowpass-$TAG_NAME.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

log_info "Packaging extension archive..."
rm -f "$ZIP_PATH"

zip -q -r "$ZIP_PATH" . \
  -x "*.git*" \
  -x "*.DS_Store*" \
  -x "*.zip" \
  -x "dist/*" \
  -x "build/*" \
  -x "scripts/*" \
  -x ".vscode/*" \
  -x ".idea/*"

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1 | tr -d ' ')
FILE_COUNT=$(unzip -l "$ZIP_PATH" | awk 'END {print $(NF-1)}')

log_success "Package created: ${BOLD}$ZIP_PATH${NC} ($ZIP_SIZE, $FILE_COUNT files)"

# Summary before releasing
echo ""
echo -e "${BOLD}Release Summary:${NC}"
echo -e "  • Tag:          ${CYAN}$TAG_NAME${NC}"
echo -e "  • Version:      ${CYAN}$TARGET_VERSION${NC}"
echo -e "  • Asset:        ${CYAN}$ZIP_NAME${NC} ($ZIP_SIZE)"
echo -e "  • Draft:        $([[ "$IS_DRAFT" == true ]] && echo "${YELLOW}Yes${NC}" || echo "No")"
echo -e "  • Pre-release:  $([[ "$IS_PRERELEASE" == true ]] && echo "${YELLOW}Yes${NC}" || echo "No")"
echo -e "  • Notes:        $([[ -n "$CUSTOM_NOTES" ]] && echo "Custom" || echo "Auto-generated via GitHub")"
echo ""

if [[ "$AUTO_CONFIRM" != true ]]; then
  read -r -p "Publish release to GitHub? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
    log_warn "Release cancelled by user. Archive remains at $ZIP_PATH."
    exit 0
  fi
fi

# Build gh release create arguments
GH_ARGS=(
  release create "$TAG_NAME" "$ZIP_PATH"
  --title "FlowPass $TAG_NAME"
)

if [[ "$IS_DRAFT" == true ]]; then
  GH_ARGS+=(--draft)
fi

if [[ "$IS_PRERELEASE" == true ]]; then
  GH_ARGS+=(--prerelease)
fi

if [[ -n "$CUSTOM_NOTES" ]]; then
  GH_ARGS+=(--notes "$CUSTOM_NOTES")
else
  GH_ARGS+=(--generate-notes)
fi

log_info "Creating GitHub release with gh CLI..."
gh "${GH_ARGS[@]}"

log_info "Syncing local git tags..."
git fetch origin --tags -q

RELEASE_URL="https://github.com/zephinax/flowpass/releases/tag/$TAG_NAME"
echo ""
log_success "Release ${BOLD}$TAG_NAME${NC} successfully published!"
echo -e "URL: ${BOLD}${GREEN}$RELEASE_URL${NC}"
