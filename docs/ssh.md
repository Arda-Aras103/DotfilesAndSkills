# SSH Key Setup for GitHub (WSL / Linux)

Since 2021, GitHub no longer accepts a username and password for `git push`. Instead of entering a password or token on every push, you can set up an SSH key once and avoid the problem permanently.

## 1. Check whether you already have an SSH key

```bash
ls -al ~/.ssh
```

If you see a file such as `id_ed25519` or `id_rsa`, you already have a key and can skip to step 2.

## 2. Create a new SSH key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

At the prompts:

- Press Enter to accept the default file location.
- For the passphrase, you can press Enter to leave it empty. You may also set one for extra security, but you will be asked for it each time the key is used.

## 3. Copy the public key

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the whole line, from `ssh-ed25519` to your email address at the end.

## 4. Add the key to GitHub

1. Go to `https://github.com/settings/keys`.
2. Click **New SSH key**.
3. Give it a name, for example "WSL Ubuntu".
4. Paste the copied key into the **Key** box.
5. Click **Add SSH key** to save.

## 5. Test the connection

```bash
ssh -T git@github.com
```

On the first connection, you will see a host verification prompt:

```
The authenticity of host 'github.com' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Before typing `yes`, check that the fingerprint shown matches GitHub's official fingerprints at https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints . If it matches, type `yes` and press Enter.

On success, you will see:

```
Hi <your-username>! You've successfully authenticated, but GitHub does not provide shell access.
```

This message is normal. "Does not provide shell access" is expected, because SSH is only used for git operations here.

## 6. Switch an existing repo's remote URL to SSH

If you cloned the repo earlier over HTTPS (`https://github.com/...`), change the remote to SSH:

```bash
git remote set-url origin git@github.com:<your-username>/<repo-name>.git
```

Check it:

```bash
git remote -v
```

The output should look like this:

```
origin  git@github.com:your-username/repo-name.git (fetch)
origin  git@github.com:your-username/repo-name.git (push)
```

## 7. Connect a new repo over SSH from the start

```bash
git remote add origin git@github.com:<your-username>/<repo-name>.git
git push -u origin main
```

## From now on

```bash
git push origin main
```

This runs directly, without asking for a password or token.

---

## Notes

- Keep the **private** key (`id_ed25519`, the file without an extension) to yourself. Only the `.pub` public key is added to GitHub.
- On a different computer, you need to repeat these steps. Each machine has its own key.
- If you have more than one GitHub account, `~/.ssh/config` can route different keys to different accounts. That is a separate topic and can be covered if needed.
