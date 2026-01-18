# lruprune

A bash script that prunes directories to a target size by deleting the least recently accessed files first (LRU eviction).

Useful for managing cache directories, log folders, or any directory that grows over time and needs periodic cleanup.

## Requirements

Requires GNU coreutils (`du -sb` and `find -printf` are GNU-specific).

**macOS users:**
```bash
brew install coreutils findutils
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mmeyer2k/lruprune/main/lruprune.sh -o /usr/local/bin/lruprune
chmod +x /usr/local/bin/lruprune
```

## Usage

```
lruprune <directory> <target_size> [--delete]
```

| Argument | Description |
|----------|-------------|
| `directory` | Directory to prune |
| `target_size` | Target size with optional suffix: K, M, G, T, P |
| `--delete` | Actually delete files (without this flag, performs a dry run) |

## Examples

Preview what would be deleted to bring `/var/cache` under 500MB:
```bash
lruprune /var/cache 500M
```

Actually delete files to bring a directory under 10GB:
```bash
lruprune /home/user/downloads 10G --delete
```

## Output

The script outputs each file that would be (or was) deleted in the format:
```
[DRY RUN] 2024-01-15+10:30:45    1048576    /path/to/file
```

Followed by a summary:
```
Summary: Would delete 5 file(s), freeing 52428800 bytes
```

## License

MIT
