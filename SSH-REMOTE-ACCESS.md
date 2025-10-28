# SSH Remote Access Configuration Guide

## Prerequisite: Generate SSH Key on Controlling Machine

1. Generate SSH Key:
```powershell
ssh-keygen -t ed25519 -C "remote-management@cjc.local"
```

2. Copy Public Key to Target Machine:
```powershell
# Windows to Windows
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh username@target-machine 'mkdir -p .ssh && cat >> .ssh/authorized_keys'

# macOS equivalent
cat ~/.ssh/id_ed25519.pub | ssh username@target-machine 'mkdir -p .ssh && cat >> .ssh/authorized_keys'
```

## Test SSH Connection
```powershell
ssh username@target-machine
```

## Troubleshooting
- Ensure firewall allows SSH (port 22)
- Verify username and credentials
- Check SSH service is running