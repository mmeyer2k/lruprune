#!/usr/bin/env bash

# Requires GNU coreutils (find -printf is GNU-specific)
# On macOS, install with: brew install findutils
# Then use: export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"

# Check for GNU find
if ! find --version 2>/dev/null | grep -q 'GNU'; then
  echo "Error: GNU findutils required. On macOS: brew install findutils" >&2
  exit 1
fi

# Function to convert size with magnitude suffix to bytes
convert_to_bytes() {
  local size=$1

  # Validate that the size is a valid number with an optional suffix
  if [[ ! "$size" =~ ^([0-9]+)([KMGTP]?)$ ]]; then
    echo "Error: Invalid target size format '$size'. Must be a number followed by an optional K, M, G, T, P suffix." >&2
    return 1
  fi

  local number=${BASH_REMATCH[1]}  # Extract the numeric part
  local suffix=${BASH_REMATCH[2]}  # Extract the suffix part

  case "$suffix" in
    K)  echo $(( number * 1024 )) ;;  # Kilobytes
    M)  echo $(( number * 1024 * 1024 )) ;;  # Megabytes
    G)  echo $(( number * 1024 * 1024 * 1024 )) ;;  # Gigabytes
    T)  echo $(( number * 1024 * 1024 * 1024 * 1024 )) ;;  # Terabytes
    P)  echo $(( number * 1024 * 1024 * 1024 * 1024 * 1024 )) ;;  # Petabytes
    "") echo "$number" ;;  # No suffix means it's in bytes already
    *)  echo "Error: Unsupported size suffix '$suffix'" >&2 && return 1 ;;  # Unsupported suffix
  esac
}

# Check if the correct number of arguments is provided
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <directory> <target_size> [--delete]"
  echo "  <directory>          Directory to check"
  echo "  <target_size>        Target size (e.g., 10G, 500M)"
  echo "  --delete             Delete files to reach the target size"
  exit 1
fi

# Check if the target size is a valid positive value with a valid suffix
target=$(convert_to_bytes "$2")
if [[ $? -ne 0 ]]; then
  echo "Error: Invalid target size format." >&2
  exit 1
fi

# Check if the directory exists
if [[ ! -d "$1" ]]; then
  echo "Error: Directory '$1' does not exist." >&2
  exit 1
fi

echo "Calculating size of [$1]..."

# Calculate total logical size using find
# Note: This sums the logical size of all files
total_size=$(find "$1" -type f -printf "%s\n" | awk '{ sum += $1 } END { print sum+0 }')

if [[ -z "$total_size" ]]; then
  total_size=0
fi

echo "Size of [$1] is $total_size bytes"
echo "Target size is $target bytes"

# Determine if we're in dry run or delete mode
dry_run=true
if [[ "$3" == "--delete" ]]; then
  dry_run=false
else
  echo "Performing dry run..."
fi

# Exit early if the directory is already below the target size
if (( total_size <= target )); then
  echo "Directory size is already below the target size. No action needed."
  exit 0
fi

# Calculate how much to delete
amount_to_delete=$(( total_size - target ))

echo "Need to delete $amount_to_delete bytes..."

# Track summary statistics
total_freed=0
files_deleted=0

# Use find to get files sorted by size (newest first? or largest first?)
# Here, we sort by size descending to delete largest files first (efficient)
# Use -print0 and xargs -0 for safe filename handling
# Note: This approach deletes files in batches, not one by one with size tracking.
# To track size precisely, we need to process files one by one.

# Alternative: Process files one by one with find and awk
# This is slower but more accurate for size tracking.

# Let's use a while loop with find and awk for accurate size tracking
# But use -print0 and read -d '' for safe filename handling

current_freed=0
while IFS= read -r -d '' file_info; do
  # file_info is in the format: "size\tfilename"
  file_size="${file_info%%	*}"  # Get size (before tab)
  file_name="${file_info#*	}"  # Get filename (after tab)

  if (( current_freed >= amount_to_delete )); then
    break
  fi

  current_freed=$(( current_freed + file_size ))
  total_freed=$(( total_freed + file_size ))
  files_deleted=$(( files_deleted + 1 ))

  if [[ "$dry_run" == false ]]; then
    rm -f "$file_name"  # Delete the file
    echo "Deleted: $file_name ($file_size bytes)"
  else
    echo "[DRY RUN] Would delete: $file_name ($file_size bytes)"
  fi
done < <(find "$1" -type f -printf "%s\t%p\0" | sort -z -t $'\t' -k1,1 -rn)

# Print summary
echo ""
if [[ "$dry_run" == true ]]; then
  echo "Summary: Would delete $files_deleted file(s), freeing $total_freed bytes"
else
  echo "Summary: Deleted $files_deleted file(s), freed $total_freed bytes"
fi
