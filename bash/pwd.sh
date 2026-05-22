bwfind() {
  if [ -z "$1" ]; then
    echo "Usage: bwfind <search-term>"
    return 1
  fi

  if [ -z "$BW_SESSION" ]; then
    echo "Please unlock Bitwarden first: export BW_SESSION=\$(bw unlock --raw)"
    return 1
  fi

  bw list items --search "$1" |
    jq -r '["NAME", "USERNAME", "PASSWORD"], (.[] | if .type == 2 then [.name, .notes // "", ""] else [.name, .login.username // "", .login.password // ""] end) | @tsv' |
    column -t -s $'\t'
}

# Connect to FTP server using Bitwarden credentials
bwftp() {
  # Check if BW_SESSION is set
  if [ -z "$BW_SESSION" ]; then
    echo "Please unlock Bitwarden first: export BW_SESSION=\$(bw unlock --raw)"
    return 1
  fi

  # Check if required commands are available
  if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is required but not installed"
    return 1
  fi

  # Get all login items from Bitwarden and format for fzf
  # Use a temp file to avoid control character issues
  local temp_file=$(mktemp)

  # Get all items and filter for login type, then format as TSV
  bw list items 2>/dev/null | jq -r '.[] | select(.type == 1 and .login != null) | [.id, .name, (.login.username // "no-username")] | @tsv' >"$temp_file" 2>/dev/null

  if [ ! -s "$temp_file" ]; then
    rm -f "$temp_file"
    echo "No login items found in Bitwarden"
    return 1
  fi

  # Let user select and filter with fzf
  # The search term can be provided as argument or typed in fzf
  local fzf_query="${1:-}"
  local selected=$(cat "$temp_file" | fzf --query="$fzf_query" --delimiter='\t' --with-nth=2,3 --prompt="Select FTP server: " --height=40% --reverse)
  rm -f "$temp_file"

  if [ -z "$selected" ]; then
    echo "No item selected"
    return 1
  fi

  # Extract the item ID
  local item_id=$(echo "$selected" | cut -f1)

  # Get the specific item by ID (more reliable than parsing from list)
  local item=$(bw get item "$item_id" 2>/dev/null)

  if [ -z "$item" ]; then
    echo "Error: Could not retrieve item details"
    return 1
  fi

  # Extract credentials and URI
  local username=$(echo "$item" | jq -r '.login.username // ""')
  local password=$(echo "$item" | jq -r '.login.password // ""')
  local uri=$(echo "$item" | jq -r '.login.uris[0].uri // ""')

  # Validate required fields
  if [ -z "$username" ]; then
    echo "Error: No username found for selected item"
    return 1
  fi

  if [ -z "$password" ]; then
    echo "Error: No password found for selected item"
    return 1
  fi

  if [ -z "$uri" ]; then
    echo "Error: No URI found for selected item"
    return 1
  fi

  # Parse host from URI (remove protocol if present)
  local host=$(echo "$uri" | sed -E 's|^[a-zA-Z]+://||' | sed -E 's|/.*$||')

  # Construct lftp command
  local lftp_cmd="lftp -u ${username},${password} ftp://${host} -e \"set ssl:verify-certificate no\""

  # Display command with masked password
  echo "Executing: lftp -u ${username},*** ftp://${host}"
  echo ""

  # Execute the command
  eval "$lftp_cmd"
}
