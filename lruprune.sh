#!/usr/bin/env bash

# Function to convert size with magnitude suffix to bytes
convert_to_bytes() {
  local size=$1

  # Validate that the size is a valid number with an optional suffix
  if [[ ! "$size" =~ ^([0-9]+)([KMGTP]?)$ ]]; then
    echo "Error: Invalid target size format '$size'. Must be a number followed by an optional K, M, G, T suffix."
    return 1
  fi

  local number=${BASH_REMATCH[1]}  # Extract the numeric part
  local suffix=${BASH_REMATCH[2]}  # Extract the suffix part

  case "$suffix" in
    K)  echo $(( number * 1024 )) ;;  # Kilobytes
    M)  echo $(( number * 1024 * 1024 )) ;;  # Megabytes
    G)  echo $(( number * 1024 * 1024 * 1024 )) ;;  # Gigabytes
    T)  echo $(( number * 1024 * 1024 * 1024 * 1024 )) ;;  # Terabytes
    "") echo "$number" ;;  # No suffix means it's in bytes already
    *)  echo "Error: Unsupported size suffix '$suffix'" && return 1 ;;  # Unsupported suffix
  esac
}

# Check if the correct number of arguments is provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 <directory> <target_size> [--delete!]"
  echo "  <directory>          Directory to check"
  echo "  <target_size>        Target size (e.g., 10G, 500M)"
  echo "  --delete             Delete files to reach the target size"
  exit 1
fi

# Check if the target size is a valid positive value with a valid suffix
target=$(convert_to_bytes "$2")
if [ $? -ne 0 ]; then
  echo "Error: Invalid target size format."
  exit 1
fi

echo "Calculating size of [$1]..."

# Run the du command and check for failure
du_output=$(du -sb "$1")
du_exit_code=$?

# Check if the du command failed
if [ $du_exit_code -ne 0 ]; then
  echo "Error: Failed to calculate the size of the directory '$1'. Please check if the directory exists and if you have the necessary permissions."
  exit 1
fi

# Extract the size from the du output
actual=$(echo "$du_output" | cut -f 1)

echo "Size of [$1] is $actual bytes"
echo "Target size is $target bytes"

if [ "$3" != "--delete" ]; then
  echo "Performing dry run..."
fi

# Exit early if the directory is already below the target size
if (( actual <= target )); then
  echo "Directory size is already below the target size. No action needed."
  exit 0
fi

while read -r line; do
  # Exit if the actual size is less than the target size
  if (( actual < target )); then
    exit 0
  fi

  freed=$(echo "$line" | cut -f 2)
  actual=$(( actual - freed ))  # Decrease actual size

  filename=$(echo "$line" | cut -f 3)

  if [ "$3" == "--delete" ]; then
    rm -f "$filename"  # Delete the file
  fi

  echo "$line"
done < <(find "$1" -type f -printf "%A+\t%s\t%p\n" | sort)
