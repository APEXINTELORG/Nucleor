# Tab completion for the Nucleor CLI

Drop-in completions for `nuc` (and the long form `nucleor`) across the four
shells most users will reach for.

## bash

```
source /path/to/Nucleor_OSS/tools/completions/nuc.bash
```

Or symlink into the system bash-completion directory:

```
sudo ln -s "$(pwd)/tools/completions/nuc.bash" /etc/bash_completion.d/nuc
```

## zsh

Add the completions directory to your `fpath` and reinitialize compinit:

```
fpath=(/path/to/Nucleor_OSS/tools/completions $fpath)
autoload -U compinit && compinit
```

## fish

Copy the file into your user completions:

```
cp /path/to/Nucleor_OSS/tools/completions/nuc.fish ~/.config/fish/completions/
```

Fish picks it up automatically the next time you open a shell.

## PowerShell

In your `$PROFILE` (run `notepad $PROFILE` if it doesn't exist yet), add:

```
. C:\path\to\Nucleor_OSS\tools\completions\nuc-completion.ps1
```

Reload the profile (`. $PROFILE`) and tab completion is wired up for both
`nuc` and `nucleor` commands.

## What completes

- **Subcommand at position 1:** `build`, `run`, `test`, `bench`, `perf`,
  `check`, `emit`, `clean`, `scram`, `zen`, `mco`, `init`, `bootstrap`,
  and the rest of the surface (~37 commands).
- **Flags after a subcommand:** `-o`, `--time-passes`, `--no-cache`,
  `--tier`, `--json`, `--iterations`, etc.
- **Source files:** `.nr` files in the current and child directories.

## Updating

If you add a new subcommand or flag to the compiler, update each of the four
files in this directory. The scripts intentionally hard-code the surface
rather than introspecting at completion time — keeps tab completion fast
and removes the need to launch `nuc.exe` for every TAB press.
