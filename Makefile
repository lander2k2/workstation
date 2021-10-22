all: config-dir tmux gitconfig kind starship vim zsh

config-dir:
	mkdir -p ~/.config

tmux:
	cp tmux-setup /usr/local/bin/

gitconfig:
	cp gitconfig ~/.gitconfig

kind: config-dir
	mkdir -p ~/.config/kind
	cp default-kind.yaml ~/.config/kind/default.yaml

starship: config-dir
	cp starship.toml ~/.config/starship.toml

vim:
	cp vimrc ~/.vimrc

zsh:
	cp zshenv ~/.zshenv
	cp zshrc ~/.zshrc

