# Puts this project's toolchain on your PATH.
#
# Everything it needs lives under ~/.local rather than system-wide, because this machine has no
# root: the Erlang and Elixir builds, the shared libraries the ERTS links against, and the ones
# Playwright's Chromium links against. Without these, `mix` is not a command and the browser
# suites cannot launch.
#
# Add this to ~/.bashrc and you never think about it again:
#
#     [ -f ~/mini-lineage-remastered/env.sh ] && source ~/mini-lineage-remastered/env.sh
#
# Safe to source repeatedly, and safe on a machine where any of it was installed properly:
# directories that do not exist are skipped.

case ":$PATH:" in
  *":$HOME/.local/lib/otp/bin:"*) ;;
  *) export PATH="$HOME/.local/lib/otp/bin:$HOME/.local/lib/elixir/bin:$HOME/.local/usr/bin:$HOME/.mix/escripts:$PATH" ;;
esac

for _ml_lib in "$HOME/.local/usr/lib/x86_64-linux-gnu" "$HOME/.local/lib/playwright-deps"; do
  [ -d "$_ml_lib" ] || continue
  case ":${LD_LIBRARY_PATH:-}:" in
    *":$_ml_lib:"*) ;;
    *) export LD_LIBRARY_PATH="$_ml_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
  esac
done
unset _ml_lib

# Node comes from nvm, which only puts itself on the PATH of an interactive shell — so a script,
# a mix task or an editor terminal can find `mix` and still not find `node`.
if ! command -v node >/dev/null 2>&1 && [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh" --no-use
  nvm use --silent default >/dev/null 2>&1 || nvm use --silent node >/dev/null 2>&1
fi

# This game is made of emoji, and the VM warns that Elixir may malfunction under latin1.
[ -n "${LANG:-}" ] || export LANG=C.UTF-8
