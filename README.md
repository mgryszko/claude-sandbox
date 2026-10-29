# sclaude

`sclaude`, short for sandboxed Claude, runs Claude Code in a [mise sandbox](https://mise.jdx.dev/sandboxing.html) (macOS Seatbelt).
Claude can write only to the folders you list and sees only the environment variables you list.
The list lives in a config file that the sandbox itself can't write, so Claude can't widen its own policy.

## Requirements

- macOS. Linux has a mise sandbox too, but this script is untested there.
- [mise](https://mise.jdx.dev) with the `exec --allow-write/--allow-env` flags, tested with 2026.10.17.
- Claude Code on your `PATH` as `claude`.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/mgryszko/sclaude/main/install.sh | sh
cd ~/my-project && sclaude
```

The installer:

- checks that `mise` and `claude` are on your `PATH`,
- downloads the script of the latest release to `~/.local/bin`, or to `SCLAUDE_BIN_DIR` if you set it,
- writes the default config if you have none,
- prints the line to add to your shell profile when the folder isn't on your `PATH`. macOS doesn't put `~/.local/bin`
  on it, but Claude Code's own installer asks you to, so it is usually there already.

The first start in a folder asks to add it as a project (see below).

Keep the script outside every project and writable path.
The sandbox could otherwise change the script that starts it, and `sclaude` refuses to start.

### Update

```sh
sclaude sandbox version   # the installed version
sclaude sandbox update    # install the latest release over the script
```

Once a day, when Claude starts in a terminal, `sclaude` asks GitHub for the latest release, waiting at most
two seconds. If there is a newer one, it prints a line with the `update` command and starts Claude as usual.
It never updates by itself. Set `SCLAUDE_NO_UPDATE_CHECK=1` to turn the check off.

`update` refuses inside the sandbox, which can't write the script, and when the script is in a git clone,
which you update with `git pull`.

The installer and the updater trust GitHub and this repository's owner, as any `curl | sh` install does.

## Configure

The config is at `~/.config/sclaude/config`, or wherever `SCLAUDE_CONFIG` points.
Change it outside the sandbox, with the `sclaude` command, with the `sandbox-config` skill, or by hand
(see [Sections](#sections)). Changes apply the next time Claude starts.

### With the sclaude command

Run these from a normal terminal:

```sh
sclaude sandbox show              # the config with paths expanded
sclaude sandbox add-project DIR   # Claude may start in DIR and write to it
sclaude sandbox add-write PATH    # Claude may write to PATH
sclaude sandbox add-env 'AWS_*'   # pass variables into the sandbox
sclaude sandbox remove ENTRY
sclaude sandbox help              # all commands, version and update included
```

`sclaude --help` shows Claude Code's own help, since every argument outside `sandbox` goes to `claude`.

Started in a folder outside every project, `sclaude` asks whether to add that folder as a project:

```
sclaude: /Users/me/new-project is not in a project listed in ~/.config/sclaude/config. Add it as a project? [y/N]
```

On `y` it adds the folder to `[projects]` and starts Claude. Anything else stops it, with the `add-project` command to run later.
The question comes before the sandbox starts, so Claude can't answer it, and the folder goes through the same guard as
`add-project`. Without a terminal, for example `sclaude -p` in a script, it doesn't ask: it stops and prints the command.

### With the sandbox-config skill

The `sandbox-config` skill does the first setup and later changes for you, by running the commands above.
Install it as a plugin, in Claude started without the sandbox:

```sh
claude plugin marketplace add mgryszko/sclaude
claude plugin install sclaude@sclaude
```

Then, in Claude started without the sandbox, ask it to set up the sandbox, or paste it the error a sandboxed session
reported. It shows the commands it would run and waits for your go-ahead, since each one widens the sandbox.
Inside the sandbox it stops and lists the commands for you to run outside, since it couldn't change the config there.

### Default config

`sclaude sandbox init` writes this file, here without its comments:

```ini
[projects]

[write]
~/.claude
~/.claude.json
~/.local/state/claude
$TMPDIR

[env]
ANTHROPIC_*
CLAUDE_*
LC_*
```

It allows only what Claude Code needs to run:

- no project, so the first start asks to add the current folder,
- writes to Claude's config folder, `~/.claude.json`, its lock files in `~/.local/state/claude` and the temporary folder,
- the variables Claude reads for its login and settings, and the locale.

Add everything else yourself, for example the caches of the tools Claude runs (`~/.cache/uv`, `~/.npm`, `~/.gradle`).
Without a config file, `sclaude` refuses to start and tells you to run `init`.

### Sections

| Section | An entry is | `*` | Empty or missing |
|---|---|---|---|
| `[projects]` | a folder Claude may start in and write to | not supported, rejected | Claude starts nowhere until you add a folder, at the question above or with `add-project` |
| `[write]` | a file or folder Claude may write to | not supported, rejected | Claude writes only to `/tmp` and `/dev`, not even to its own config |
| `[env]` | a variable, or a pattern such as `AWS_*` | passes every variable | only `PATH HOME USER SHELL TERM COLORTERM LANG` pass |

A missing section is the same as an empty one: it allows nothing.
`sclaude` always passes `--deny-write` and `--deny-env` to mise, so nothing is allowed unless an entry allows it.

`*` in `[env]` passes every variable from your shell into the sandbox, including tokens and keys such as
`GITHUB_TOKEN` or `AWS_SECRET_ACCESS_KEY`. Prefer a pattern for the tools you use, such as `AWS_*`.

Paths in `[projects]` and `[write]` are absolute or start with `~`, `$HOME` or `$TMPDIR`. No other variables are expanded,
and no wildcards: mise doesn't support them in writable paths.
`#` starts a comment, at the start of a line or after an entry.

### Second Claude config folder

To use a second Claude config folder, add it to `[write]` and point `CLAUDE_CONFIG_DIR` at it:

```sh
sclaude sandbox add-write ~/.claude-personal
CLAUDE_CONFIG_DIR=~/.claude-personal sclaude
```

Both folders are then writable from either one.
For separate lists, give the second one its own config file with `SCLAUDE_CONFIG`.

### Login

Claude Code keeps its login in the macOS Keychain, and the default config doesn't let Claude write `~/Library/Keychains`.
If Claude in the sandbox loses its login or can't refresh it, either add `~/Library/Keychains` to `[write]`,
or run `claude setup-token` once and export the token as `CLAUDE_CODE_OAUTH_TOKEN`, which `CLAUDE_*` lets through.

## What protects the config

When it starts, and on every `add-project` and `add-write`, `sclaude` refuses a writable path that is `/`,
or that contains or sits inside one of these:

- the config file,
- the `sclaude` script, both the link on your `PATH` and its target,
- the `claude` and `mise` binaries, both the links and their targets,
- mise's global config folder, `~/.config/mise` or `MISE_CONFIG_DIR`.

These are what runs or is read outside the sandbox when Claude starts.

## herdr

After a restart, [herdr](https://herdr.dev) resumes a Claude pane with `claude --resume <id>`, which would bring a sandboxed
session back without the sandbox.
In a herdr pane, `sclaude` adds a SessionStart hook that tells herdr to resume with `sclaude --resume <id>` instead,
with `CLAUDE_CONFIG_DIR` in front when it is set.
The hook reports again after `/clear`, `/compact` and `--resume`, so herdr always holds the current session.

For the hook, and for herdr's own Claude integration, `sclaude` passes `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_SOCKET_PATH`
and `HERDR_BIN_PATH` into the sandbox without an `[env]` entry. They name the pane and herdr's socket, nothing secret.
Herdr types the command into the pane's shell, so `sclaude` must be on your `PATH` under that name.

Herdr's socket is reachable from inside the sandbox, which lets a sandboxed Claude type into your other panes. See
[herdr and other terminal multiplexers](#herdr-and-other-terminal-multiplexers).

## Limitations

### mise

- mise reads its config, installs tools and runs hooks outside the sandbox. Only the command it starts is sandboxed.
  Started in a project, mise would load the project's `mise.toml` and `mise.local.toml`, which Claude can write.
  A hook or an `[env] _.source` line added there would then run without the sandbox the next time Claude starts.
  `sclaude` therefore starts mise in `/`, where it reads only the global config, and changes into the project inside the
  sandbox. The project's tools still reach Claude through the mise shims or `mise activate` in your shell profile, which run
  inside the sandbox.
- The guard knows only `~/.config/mise` or `MISE_CONFIG_DIR`. If your global mise config lives elsewhere, keep it out of
  every writable path.
- Reads aren't restricted. Claude can read the whole disk, including `~/.ssh` and `~/.aws/credentials`.
- Network access isn't restricted. mise can block the whole network, which would also cut Claude off from its API,
  but it can't allow single hosts on macOS or Linux.
- `PATH HOME USER SHELL TERM COLORTERM LANG` always pass, and `/tmp` and `/dev` are always writable.

### Files that run later outside the sandbox

The sandbox limits what Claude writes, not what you run afterwards.
Anything Claude writes to a writable path runs without the sandbox when you use it outside, for example:

- `~/.claude`: settings with hooks, MCP servers, skills and plugins, including the `sandbox-config` skill if you install it there,
  when you start `claude` without the sandbox,
- `.git/hooks`, `mise.toml` and task files in a project, when you commit, run a task or enter the folder with `mise activate`,
- caches such as `~/.cache/uv` or `~/.npm`, when you build outside the sandbox,
- any folder on your `PATH`.

The guard protects only the config and what starts Claude. Keep the rest of the list as short as you can.

### herdr and other terminal multiplexers

The sandbox blocks writes to files, not connections to local sockets.
herdr is controlled through one, `~/.config/herdr/herdr.sock`, and a sandboxed process can connect to it.
Its `send-keys` and `prompt` commands type into any pane, including plain shells and Claude sessions started without
the sandbox. A sandboxed Claude, or a script it runs, could type a command there, and the command would run with your
full access.

- Leaving `HERDR_*` out of the sandbox doesn't help: the socket path is fixed and easy to find.
- The resume command that `sclaude` reports is a smaller case of the same: whatever command the sandbox reports runs
  outside the sandbox the next time herdr restarts.
- mise has no option to block a single socket.
- Other tools controlled through a local socket, such as tmux, likely allow the same.

Run `sclaude` in a terminal outside herdr when Claude must not reach your other sessions.

## License

[0BSD](LICENSE): use, copy, change and share it for any purpose, with no attribution needed.
