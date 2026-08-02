# VPS Setup Guide

A step-by-step guide for provisioning a fresh VPS with Tailscale, a Neovim
config, Claude, and Telegram integration.

## 1. Install Tailscale

```sh
curl -fsSL https://tailscale.com/install.sh | sh
```

Log in — you should see the new IP alongside your other Tailscale devices.

- Get the new Tailscale IP: `tailscale ip -4`
- Check status from the CLI: `tailscale status`

## 2. Configure the Firewall (UFW)

```sh
# Allow all internal traffic over the Tailscale interface
sudo ufw allow in on tailscale0

# Enable UFW
sudo ufw enable
```

## 3. Set Up SSH

Add the Tailscale IPs to your SSH config as usual.

> On iOS, [Terminus](https://termius.com/) works well as the SSH client.

## 4. Install Base Packages & tmux

```sh
sudo apt update && sudo apt install -y build-essential procps curl file git tmux
```

## 5. Install the Neovim Config

### Install Homebrew

```sh
sudo apt-get install build-essential procps curl file git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Add the Homebrew binary to your PATH:

```sh
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

### Install Neovim dependencies

Install `gcc`, `tree-sitter`, `tree-sitter-cli`, and `ripgrep` via Homebrew.

### Clone the kickstart config

```sh
git clone git@github.com:edwardhutchinson/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
```

Launch Neovim — Mason will install everything automatically. 🎉

## 6. Install Claude

See the [quickstart docs](https://code.claude.com/docs/en/quickstart).

```sh
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## 7. Install lazygit

Install via Homebrew (or your preferred method).

## 8. Clone the `unbloated` Repo

Clone the repo and install the skills.

## Claude Telegram Setup

### Create a bot

Create a new bot with [BotFather](https://t.me/botfather). You'll receive a bot
token — record it somewhere safe.

### Install bun

Install [bun](https://bun.sh/) (required for Claude channels).

### Configure the plugin

In your Claude session:

```
/plugin install telegram@claude-plugins-official
/telegram:configure YOUR-BOT-TOKEN
```

### Start the Telegram channel

Exit the session, then relaunch with the channel enabled:

```sh
claude --channels plugin:telegram@claude-plugins-official
```

> You may need to run `/reload-plugins` — this step can be finicky.

### Pair your account

DM your bot on Telegram (the Claude channel should now be listening). You'll
receive an access code, then run:

```
/telegram:access pair CODE
```

You're good to go.

## Aliases

_TODO: add useful shell aliases here._
