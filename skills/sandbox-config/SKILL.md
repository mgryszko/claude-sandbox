---
name: sandbox-config
description: Set up or change the config of sclaude, the wrapper that runs Claude Code in a mise sandbox - the first setup, adding a project, letting the sandbox write a path or see an environment variable, removing an entry, showing what is allowed. Use when the user asks to set up, configure, widen or narrow the sandbox, when a sandboxed session reported "Operation not permitted", a blocked path, missing credentials or a missing variable, or when sclaude refused to start ("not in a project listed", "overlaps"). Runs only outside the sandbox.
---

# Configure sclaude

`sclaude` reads which folders Claude may write and which environment variables it sees from a config file.
The sandbox can't write that file, so this skill works only in Claude started without the sandbox.
Make every change through `sclaude sandbox ...`: the commands check each path against the guard
that keeps the sandbox from changing what runs outside it.

## 1. Check where you run

```sh
echo "${SCLAUDE_SANDBOXED:-}"
```

If it prints `1`, stop. Tell the user to run this skill from Claude started with plain `claude`,
or to run the commands you would have run in a normal terminal, and list those commands.
Don't try to write the config another way.

## 2. Find the config

```sh
sclaude sandbox path
sclaude sandbox show
```

If `sclaude` isn't on `PATH`, ask the user where the repo is and follow its README to install it.
If `show` fails with "no config", do the first setup. Otherwise do the change the user asked for.

## 3. First setup

1. Run `sclaude sandbox init`. The default allows only what Claude Code needs to run.
2. Ask which folders Claude should work in. Each becomes `add-project`. Suggest the current folder or its git root,
   never `~` or a folder that holds many projects.
3. Ask which tools Claude will run in the sandbox, and offer the entries from the table below.
4. Ask how Claude logs in (see the Login section of the README): add `~/Library/Keychains` only if the user chooses it.
5. Show the full list of commands and wait for the user's go-ahead before running them. Each one widens the sandbox.
6. Run them and show `sclaude sandbox show`.

| Tool | Entries |
|---|---|
| AWS CLI with SSO | `add-write ~/.aws/sso/cache`, `add-write ~/.aws/cli/cache`, `add-env 'AWS_*'` |
| uv | `add-write ~/.cache/uv` |
| uv tools and `uvx` | `add-write ~/.local/share/uv/tools`. Warn first: Claude could then change the tools you installed with `uv tool install` and run outside the sandbox. |
| marimo | `add-write ~/.local/state/marimo`, where marimo registers its running servers |
| npm | `add-write ~/.npm` |
| Bun | `add-write ~/.bun/install/cache` |
| Gradle | `add-write ~/.gradle` |
| Kotlin | `add-write "$HOME/Library/Application Support/kotlin"` |
| Editor and pager | `add-env EDITOR`, `add-env PAGER` |
| Time zone | `add-env TZ` |

## 4. Change the config

When the user brings an error from a sandboxed session, find the path or variable it names.
"Operation not permitted" on a write names a path. Missing credentials or config usually mean a missing variable
or a cache the tool can't write. If the error doesn't name it, ask the user to run the failing command again
inside the sandbox and paste the full output.

Propose the narrowest entry that fixes it: the cache folder the tool writes, not its parent, and a variable or a
`PREFIX_*` pattern, never `*`. Say in one line what the entry lets Claude do. Run it only after the user agrees.

Never propose these, and if the user asks for one, explain what it lets the sandbox do first:

- `~`, `~/.config`, `~/.local/share`, `~/.local/bin` or any folder on `PATH`: Claude could replace programs you run outside.
  `~/.local/share/uv/tools` from the table above is the one folder below them to offer, with its warning.
- Shell profiles, `~/.ssh`, `~/.gitconfig`: Claude could change what your shell or git runs.
- `~/Library/Keychains`, except for Claude's own login as in the first setup.
- `add-env '*'`: Claude would see every variable in the shell, including tokens and keys.

When a command fails with "overlaps", the path would let the sandbox change what starts it.
Don't look for a way around it; tell the user which protected file it overlaps.

To remove an entry, run `sclaude sandbox remove ENTRY` with the entry as `show` prints it or as written in the file.

## 5. Finish

Show `sclaude sandbox show` and tell the user that the change applies the next time they start `sclaude`.
A running sandboxed session keeps its old policy.
