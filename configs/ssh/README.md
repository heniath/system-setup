# SSH policy

SSH changes are manual because a mistake can lock out a remote workstation.

1. Install and enable OpenSSH only when remote access is required.
2. Create a modern key on the client, protect it with a passphrase, and add only
   the **public** key to the workstation's `~/.ssh/authorized_keys`.
3. Test key login in a second terminal while the original session remains open.
4. Only after successful verification, consider disabling password authentication.
5. Keep root login disabled and use a named user plus `sudo`.
6. Enable the service at boot only after reviewing its configuration.
7. Permit the SSH port through the firewall only for necessary networks. Avoid
   broad public exposure and consider rate limiting or upstream firewall rules.
8. Validate configuration with `sudo sshd -t` before restarting the service.

For machines behind NAT, optional Tailscale can provide authenticated private
networking without router port forwarding. Review its device/account policy and
do not commit Tailscale auth keys. Keep private SSH keys and host-specific trust
data out of this repository.
