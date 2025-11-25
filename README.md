# xpandr

## What is xpandr?

**xpandr** lets you type a short trigger at your shell prompt and have it expand into a full command when you hit <kbd>Space</kbd> or <kbd>Enter</kbd>.

- Type `gcm␣`  
- Get `git commit -m ""` with the cursor between the quotes

It’s like tiny command templates wired directly into your prompt — with shared triggers for **Zsh** and **Bash**.

This tool is inspired by the excellent [zsh-abbr](https://github.com/olets/zsh-abbr).
---

## Features

- **SHORT → expansion**  
  Define a SHORT trigger and the command it should expand to.

- **Scoped multi-word triggers**  
  SHORT can be a single word (`gc`) *or* two words (`git cm`). xpandr always prefers
  the longest match at the end of the line:
  - `xpandr add "git cm" 'git commit -m "%|"'`
  - `git cm␣` → `git commit -m ""`
  - `cm␣` alone does nothing (unless you also define `cm`)

- **Cursor markers**  
  Use `%|` in an expansion to control where the cursor lands after expansion:
  ```bash
  xpandr add gcm 'git commit -m "%|"'
````

* **No daemon**
  No background service. xpandr runs as a regular CLI; shell integrations call it on demand and/or load triggers into memory.

* **Simple file format**
  Triggers are stored as a flat JSON object under:

  ```text
  ${XDG_CONFIG_HOME:-$HOME/.config}/xpandr/triggers.json
  ```

* **First-class Zsh & Bash support**
  Thin integration scripts:

  * `xpandr.zsh` for Zsh (ZLE widgets, `$LBUFFER` / `$RBUFFER`)
  * `xpandr.sh` for Bash (Readline hooks, `READLINE_LINE` / `READLINE_POINT`)

* **Script-friendly output**
  `xpandr dump` emits `SHORT<TAB>EXPANSION` lines for the shell glue, while `xpandr list` is for humans.

---

## Demo

(Imagine a GIF here.)

```console
$ xpandr add gcm 'git commit -m "%|"'

# At your shell prompt (Zsh or Bash with integration loaded):
$ gcm␣

# Becomes:
$ git commit -m ""
                   ^
                   cursor here
```

---

## Installation

### 1. Build and install the `xpandr` binary

Requires Go.

```bash
# Clone the repo
git clone https://github.com/crgr/xpandr.git
cd xpandr

# Build (stripped binary)
go build -ldflags "-s -w" -o xpandr main.go

# Put it somewhere on your PATH
mv xpandr /usr/local/bin   # or ~/.local/bin/ , etc.
```

---

## Shell integration

### Zsh

The Zsh integration lives in `xpandr.zsh` in this repository.

Copy or symlink it somewhere convenient (e.g. `~/.config/zsh/xpandr.zsh`) and source it from your `$ZDOTDIR/.zshrc`:

```zsh
source ~/.config/zsh/xpandr.zsh
```

By default, the Zsh plugin:

* expands the last SHORT trigger on <kbd>Space</kbd> and <kbd>Enter</kbd>
* understands cursor markers `%|`
* reloads triggers after `xpandr add` / `xpandr rm` in the same shell
* lets you:

  * accept the line **without expansion** using <kbd>Ctrl+J</kbd>
  * insert a **plain space without expansion** using <kbd>Ctrl+X</kbd> then <kbd>Space</kbd>

### Bash

The Bash integration lives in `xpandr.sh` in this repository.

Source it from your `~/.bashrc`:

```bash
source /path/to/xpandr.sh
```

By default, the Bash integration:

* expands the last SHORT trigger on <kbd>Space</kbd> and <kbd>Enter</kbd>
* understands cursor markers `%|`
* lets you:

  * accept the line **without expansion** using <kbd>Ctrl+J</kbd>
  * insert a **plain space without expansion** using <kbd>Ctrl+X</kbd> then <kbd>Space</kbd>

Both integrations are small and easy to tweak if you prefer different keybindings.

---

## Keybindings & suppressing expansion

With the provided Zsh/Bash integrations:

* <kbd>Space</kbd>
  Expand the last SHORT trigger (if any), then insert a space (unless a cursor marker is used).

* <kbd>Enter</kbd>
  Expand the last SHORT trigger (if any), then accept the line.

* <kbd>Ctrl+J</kbd>
  Accept the line **without** xpandr expansion.

* <kbd>Ctrl+X</kbd> then <kbd>Space</kbd>
  Insert a plain space **without** xpandr expansion.

You can change these bindings inside `xpandr.zsh` or `xpandr.sh` if you want different combinations.

---

## Usage

### Add a trigger

```bash
# Simple SHORT → expansion
xpandr add gc "git commit"

# With cursor marker
xpandr add gcm 'git commit -m "%|"'

# Scoped two-word SHORT → expansion
xpandr add "git cm" 'git commit -m "%|"'
```

### List triggers

```bash
xpandr list
# gc              -> git commit
# gcm             -> git commit -m "%|"
```

If no triggers exist, xpandr prints:

```text
No triggers defined.
```

### Remove a trigger

```bash
xpandr rm gc
```

### Dump triggers (for shell integration / scripting)

```bash
xpandr dump
# gc<TAB>git commit
# gcm<TAB>git commit -m "%|"
```

---

## Configuration & internals

xpandr stores triggers in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/xpandr/triggers.json
```

The JSON structure is a flat object:

```json
{
  "gc": "git commit",
  "gcm": "git commit -m \"%|\""
}
```

The shell integrations use `xpandr dump` to populate their internal maps, then:

- look at the end of the current line
- try to match the **last two words** against a SHORT (e.g. `git cm`)
- if no two-word SHORT matches, fall back to a **single-word** SHORT (e.g. `cm`)
- replace the matching SHORT with the expansion
- optionally move the cursor to the `%|` marker

> Note: multi-word SHORTs are matched with a single space between words, e.g. `git cm`.
> Typing `git   cm` (with multiple spaces) is not guaranteed to match.

There are no long-running processes or daemons — just a small Go binary plus thin shell glue for Zsh and Bash.

---

## License

MIT
