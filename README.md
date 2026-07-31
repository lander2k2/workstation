# workstation

Ansible playbook for setting up my workstations. Works on macOS and Linux.

Configures: zsh (+ oh-my-zsh + starship), tmux, vim, and `~/Projects` with
`work.sh`.

## Setup on a new machine

1. Install prerequisites.

   macOS — Homebrew, then ansible:

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   brew install ansible
   ```

   Debian/Ubuntu:

   ```sh
   sudo apt update && sudo apt install -y ansible git
   ```

2. Clone this repo and install the collection dependency:

   ```sh
   ansible-galaxy collection install community.general
   ```

3. Create your personal vars file:

   ```sh
   cp group_vars/all/personal.yml.example group_vars/all/personal.yml
   $EDITOR group_vars/all/personal.yml
   ```

   This file is gitignored. Either copy it across from an existing machine or
   fill it in from the example. The playbook refuses to run without it.

4. Run it:

   ```sh
   ansible-playbook site.yml --ask-become-pass
   ```

`--ask-become-pass` is needed because the playbook installs system packages and
sets your login shell.

## Usage

Run everything against this machine:

```sh
ansible-playbook site.yml --ask-become-pass
```

Preview changes without applying them:

```sh
ansible-playbook site.yml --check --diff
```

Run one part:

```sh
ansible-playbook site.yml --tags vim
```

Available tags: `packages`, `zsh`, `oh-my-zsh`, `tmux`, `vim`, `projects`.

Target a remote machine — add it under `remote` in `inventory/hosts.yml`, then:

```sh
ansible-playbook site.yml -l new-laptop --ask-become-pass
```

## Layout

```
site.yml                          playbook entrypoint
inventory/hosts.yml               localhost + any remote workstations
group_vars/all/main.yml           non-sensitive settings (committed)
group_vars/all/personal.yml       identity-specific values (gitignored)
roles/packages/                   OS packages, login shell
roles/oh_my_zsh/                  clones oh-my-zsh
roles/zsh/                        .zshenv, .zshrc, .zprofile, starship.toml
roles/tmux/                       .tmux.conf
roles/vim/                        .vimrc, pathogen, vim-plug, plugins
roles/projects/                   ~/Projects and work.sh
```

Every task that overwrites a dotfile uses `backup: true`, so the previous
version is kept alongside it with a timestamp.

## Editing configs

The zsh files are Jinja templates because they contain per-OS and per-user
values. Edit `roles/zsh/templates/*.j2`, not the generated dotfiles in `$HOME` —
the next run overwrites them.

`tmux.conf`, `vimrc` and `work.sh` are copied verbatim and can be edited
directly under `roles/*/files/`.

## What is not covered

- `~/.gitconfig` — contains a GPG signing key ID and a commit email, and the
  signing key itself will not exist on a new machine. Worth adding as a role
  once you decide how to move keys.
- Go, kubectl, krew, nvm and the threeport tooling that `.zshenv` puts on PATH.
  The PATH entries are set up; the tools are not installed.
