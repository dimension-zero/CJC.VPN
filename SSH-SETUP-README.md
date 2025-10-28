# SSH Setup Guide

## Prerequisites
- PowerShell Core installed
- Administrator/sudo access on target machines

## SSH Key-Based Authentication Setup

### 1. Generate SSH Key (on the machine you'll connect FROM)
```powershell
ssh-keygen -t ed25519 -C "your_email@example.com"
```
- Press Enter to accept default file location
- Optionally set a passphrase

### 2. Copy Public Key to Target Machine
```powershell
# For Windows
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh username@target-machine 'cat >> .ssh/authorized_keys'

# For macOS
cat ~/.ssh/id_ed25519.pub | ssh username@target-machine 'cat >> ~/.ssh/authorized_keys'
```

### Security Notes
- Never share private key (`id_ed25519`)
- Keep public key (`id_ed25519.pub`) for distribution
- Use strong passphrases
- Limit SSH access to specific users

## Troubleshooting
- Verify SSH service is running
- Check firewall settings
- Confirm key permissions