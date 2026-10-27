# Contributing

## Development

Work from a clone, with the script linked onto your `PATH`:

```sh
git clone https://github.com/mgryszko/sclaude.git ~/sclaude
ln -s ~/sclaude/bin/sclaude ~/.local/bin/sclaude
```

`sclaude sandbox update` refuses in a clone; update it with `git pull`.
Keep the clone outside every project and writable path, or `sclaude` refuses to start.

The script runs on the bash 3.2 that ships with macOS: no `mapfile`, no associative arrays,
and `${array[@]+"${array[@]}"}` for arrays that may be empty under `set -u`.
`install.sh` runs under `sh`, so it stays POSIX.

To try a change without touching your own config, point `SCLAUDE_CONFIG` at a throwaway file,
and put a fake `claude` first on `PATH` to see what reaches the sandbox:

```sh
mkdir -p /tmp/sandbox-test/bin
export SCLAUDE_CONFIG=/tmp/sandbox-test/config
sclaude sandbox init
printf '#!/bin/sh\nenv | sort\n' > /tmp/sandbox-test/bin/claude && chmod +x /tmp/sandbox-test/bin/claude
cd ~/some-project && PATH=/tmp/sandbox-test/bin:$PATH sclaude
```

Folders under `/tmp` are always writable in the sandbox, so test a refused write outside it.

Check the plugin manifest with `claude plugin validate .`.

## Releasing

The installer and the updater read the latest GitHub release, not `main`.
A tag without a release, a draft and a pre-release are all invisible to them.
`install.sh` itself is served from `main`, so a change to it is live as soon as it is pushed.

1. Set the new version in both places, to the same value:
   - `VERSION` in `bin/sclaude`,
   - `version` in `.claude-plugin/plugin.json`. Without the bump, `claude plugin update` doesn't pick up a changed skill.
2. Commit and push to `main`.
3. Tag and publish the release:

   ```sh
   gh release create v0.2.0 --target main --title v0.2.0 --generate-notes
   ```

4. Check it from a machine or a folder without a clone:

   ```sh
   SCLAUDE_BIN_DIR=/tmp/release-check sh -c "$(curl -fsSL https://raw.githubusercontent.com/mgryszko/sclaude/main/install.sh)"
   /tmp/release-check/sclaude sandbox version
   ```

Never move or delete a published tag. The updater downloads the script from the tag, so a moved tag changes what
installed copies get without a new version number. Fix a bad release with a new one.
