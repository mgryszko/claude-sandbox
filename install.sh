#!/bin/sh
# Installs the latest release of sclaude:
#   curl -fsSL https://raw.githubusercontent.com/mgryszko/sclaude/main/install.sh | sh
# Set SCLAUDE_BIN_DIR to install somewhere other than ~/.local/bin.
set -eu

repo="mgryszko/sclaude"
bin_dir="${SCLAUDE_BIN_DIR:-$HOME/.local/bin}"
target="$bin_dir/sclaude"

die() {
  echo "install: $*" >&2
  exit 1
}

[ "$(uname -s)" = Darwin ] || echo "install: sclaude is tested only on macOS" >&2
command -v mise >/dev/null 2>&1 || die "mise is not on PATH, install it first: https://mise.jdx.dev"
command -v claude >/dev/null 2>&1 || die "claude is not on PATH, install Claude Code first"
[ ! -L "$target" ] || die "$target is a link, probably into a git clone, update that clone with git pull"

tag="$(curl -fsS "https://api.github.com/repos/$repo/releases/latest" |
  sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
[ -n "$tag" ] || die "can't find the latest release of $repo"

mkdir -p "$bin_dir"
tmp="$(mktemp "$target.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
curl -fsSL "https://raw.githubusercontent.com/$repo/$tag/bin/sclaude" -o "$tmp" || die "download failed"
bash -n "$tmp" || die "the downloaded script doesn't parse"
chmod 755 "$tmp"
mv "$tmp" "$target"
echo "Installed sclaude $tag in $bin_dir"

config="$("$target" sandbox path)"
if [ -e "$config" ]; then
  echo "Kept the config at $config"
else
  "$target" sandbox init
fi

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    case "${SHELL##*/}" in
      zsh) profile="$HOME/.zshrc" ;;
      bash) profile="$HOME/.bash_profile" ;;
      *) profile="your shell profile" ;;
    esac
    echo
    echo "$bin_dir is not on your PATH. Add it, then open a new terminal:"
    echo "  echo 'export PATH=\"$bin_dir:\$PATH\"' >> $profile"
    ;;
esac

cat <<NEXT

Start Claude in a project folder with: sclaude
It asks to add the folder to the config the first time.

Optional: the sandbox-config skill sets up and changes the config for you. Install it in Claude started without the sandbox:
  claude plugin marketplace add $repo
  claude plugin install sclaude@sclaude
NEXT
