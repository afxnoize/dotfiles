# README
You should install ArchLinux/Manjaro

## dependencies
[WIP]
```sh
paru -S base-devel zip unzip git
```

## Nix / Home-Manager
### Install Nix
Use [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer)
```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

### Home-Manager
環境変数 USER, HOMEを使うため, `--impure`
```sh
cd nix
# 初回
nix run github:nix-community/home-manager -- switch --flake .#$USER_NAME --impure
# 以降
home-manager -- switch --flake .#$USER_NAME --impure
```

## chezmoi
[chezmoi](https://www.chezmoi.io/)
dotfile manager

Install
```sh
BINDIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
chezmoi update
```

## Zsh
[Zsh](https://www.zsh.org/)
shell

Install
```sh
chsh -s $(which zsh)
```

Config
```sh
# /etc/zsh/zshenv
export ZDOTDIR="$HOME"/.config/zsh
```

### zinit
Auto installed

zsh plugin manager
[zdharma-continuum/zinit: 🌻 Flexible and fast ZSH plugin manager](https://github.com/zdharma-continuum/zinit)


## mise
[mise-en-place](https://mise.jdx.dev/)

Install
```sh
curl https://mise.run | MISE_INSTALL_PATH="${LOCAL_BIN_DIR:-$HOME/.local/bin}/mise" sh
```

Usage
```sh
mise use node@20
mise use --global node@20
```

<!--
## afx
[WIP]

[AFX](https://babarot.me/afx/)


Install
```sh
curl -sL https://raw.githubusercontent.com/b4b4r07/afx/HEAD/hack/install | AFX_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}" bash
mkdir -p $XDG_CONFIG_HOME/afx
```
-->
