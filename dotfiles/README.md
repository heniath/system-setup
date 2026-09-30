# Dotfile templates

These are reviewed examples, not copies of this machine's live dotfiles. Copy or
merge them manually so existing configuration is never overwritten:

```bash
cp dotfiles/bashrc.example ~/.bashrc.system-setup-example
cp dotfiles/gitconfig.example ~/.gitconfig.system-setup-example
cp dotfiles/tmux.conf.example ~/.tmux.conf.system-setup-example
```

Inspect every file before merging it into the real destination. Do not add tokens,
private keys, passwords, credential helper storage, or machine-specific secrets.
