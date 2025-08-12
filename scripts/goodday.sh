#!/bin/bash

# Check if required environment variables are set
if [ -z "$GOODDAY_TOKEN" ] || [ -z "$GOODDAY_USER" ]; then
  echo "Error: GOODDAY_TOKEN and GOODDAY_USER environment variables must be set."
  echo "Create a .env file with your credentials and run: source .env"
  exit 1
fi

GD_HEADER="gd-api-token: $GOODDAY_TOKEN"
GD_USER="$GOODDAY_USER"
GD_URL="https://api.goodday.work/2.0"

function getId() {
  echo "$1" | grep -oP '\(\K[^()]*' | tail -1
}

function fetchTasksWithProject() {
  local tasks_file=$(mktemp)
  local projects_file=$(mktemp)

  curl -s -H "$GD_HEADER" $GD_URL/user/$GD_USER/action-required-tasks >"$tasks_file"
  curl -s -H "$GD_HEADER" $GD_URL/projects >"$projects_file"

  # Check if API calls returned valid JSON
  if ! jq empty "$tasks_file" 2>/dev/null; then
    echo "Error: Invalid response from tasks API. Check your GOODDAY_TOKEN and GOODDAY_USER." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  if ! jq empty "$projects_file" 2>/dev/null; then
    echo "Error: Invalid response from projects API. Check your GOODDAY_TOKEN and GOODDAY_USER." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  # Check if tasks response contains an error
  if jq -e '.errorMessage' "$tasks_file" >/dev/null 2>&1; then
    echo "Error: $(jq -r '.errorMessage' "$tasks_file"). Check your GOODDAY_TOKEN and GOODDAY_USER." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  # Check if projects response contains an error
  if jq -e '.errorMessage' "$projects_file" >/dev/null 2>&1; then
    echo "Error: $(jq -r '.errorMessage' "$projects_file"). Check your GOODDAY_TOKEN and GOODDAY_USER." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  # Check if tasks is an array
  if ! jq -e 'type == "array"' "$tasks_file" >/dev/null 2>&1; then
    echo "Error: Tasks API returned unexpected format. Expected array." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  # Check if projects is an array
  if ! jq -e 'type == "array"' "$projects_file" >/dev/null 2>&1; then
    echo "Error: Projects API returned unexpected format. Expected array." >&2
    rm -f "$tasks_file" "$projects_file"
    return 1
  fi

  jq --slurpfile tasks "$tasks_file" --slurpfile projects "$projects_file" -n \
    '
      [
        ($tasks[0][] as $t | select($t | has("status") and ($t.status | has("name"))) | select($t.status.name as $status_name | ["On hold", "Completed", "Dlouhodobý"] | index($status_name) | not) |
        $projects[0][] as $p | select($p.id == $t.projectId) | {task_id: $t.id, task_name: $t.name, status_name: $t.status.name, project_name: $p.name, date: $t.recentActivityMoment})
      ]
      | sort_by(.date) | reverse
      | .[] | "[\(.date[8:10]).\(.date[5:7]) \(.date[11:16])] [\(.project_name)] \(.task_name) (\(.task_id))"
      '

  rm -f "$tasks_file" "$projects_file"
}

function fetchMessagesWithUser() {
  local messages_file=$(mktemp)
  local users_file=$(mktemp)

  curl -s -H "$GD_HEADER" $GD_URL/task/$1/messages >"$messages_file"
  curl -s -H "$GD_HEADER" $GD_URL/users >"$users_file"

  jq --slurpfile messages "$messages_file" --slurpfile users "$users_file" -n \
    '
      [
        ($messages[0][] as $m | $users[0][] as $u | select($u.id == $m.fromUserId) | {text: $m.message, date: "\($m.dateCreated[8:10]).\($m.dateCreated[5:7]) \($m.dateCreated[11:16])", user: $u.name})
      ]
      '

  rm -f "$messages_file" "$users_file"
}

task=$(fetchTasksWithProject | fzf --layout=reverse)
if [ $? -ne 0 ] || [ -z "$task" ]; then
  echo "Error: Failed to fetch tasks or no task selected."
  exit 1
fi
taskId=$(getId "$task")
echo "$taskId"

echo "What you want to do:"
options=("Reply" "Detail" "Open" "Export to file")
user_selection=$(printf '%s\n' "${options[@]}" | fzf --layout=reverse)

# React based on user selection
case $user_selection in
"Open")
  echo "Opening the browser with  $taskId..."
  xdg-open "https://www.goodday.work/t/$taskId"
  ;;
"Detail")
  echo "Opening details..."
  echo "$task" | fold -s -w 64
  echo "================================================================"
  messages=$(fetchMessagesWithUser "$taskId")
  length=$(echo "$messages" | jq '. | length')
  for ((i = 0; i < $length; i++)); do
    text=$(echo "$messages" | jq -r ".[$i].text")
    date=$(echo "$messages" | jq -r ".[$i].date")
    user=$(echo "$messages" | jq -r ".[$i].user")
    if [[ ! -z "$text" && "$text" != "null" ]]; then
      echo -e "${BOLD}$user${CLEAR}"
      echo -e "${UNDERLINE}$date${CLEAR}"
      echo -e "$text" | fold -s -w 64
      echo "================================================================"
    fi
  done
  ;;
"Export to file")
  echo "Exporting task details to task.md..."
  {
    echo "# Task Details"
    echo ""
    echo "$task" | fold -s -w 64
    echo ""
    echo "================================================================"
    echo ""
    messages=$(fetchMessagesWithUser "$taskId")
    length=$(echo "$messages" | jq '. | length')
    for ((i = 0; i < $length; i++)); do
      text=$(echo "$messages" | jq -r ".[$i].text")
      date=$(echo "$messages" | jq -r ".[$i].date")
      user=$(echo "$messages" | jq -r ".[$i].user")
      if [[ ! -z "$text" && "$text" != "null" ]]; then
        echo "**$user**"
        echo ""
        echo "*$date*"
        echo ""
        echo "$text" | fold -s -w 64
        echo ""
        echo "================================================================"
        echo ""
      fi
    done
  } > task.md
  echo "Task details exported to task.md"
  ;;
"Reply")
  echo "$task"
  echo "Change status:"
  statuses=$(curl -s -H "$GD_HEADER" $GD_URL/statuses)
  status=$(echo $statuses | jq -r '.[] | .name + " (" + .id + ")"' | fzf --layout=reverse)
  status_id=$(getId "$status")
  url=
  echo "Change AR:"
  users=$(curl -s -H "$GD_HEADER" $GD_URL/users)
  ar_user=$(echo $users | jq -r '.[] | .name + " (" + .id + ")"' | fzf --layout=reverse)
  ar_user_id=$(getId "$ar_user")
  echo "Selected user: $ar_user_id"
  echo "Your reply text:"
  read user_reply
  echo "Time report:"
  minutes=(0 5 10 15 30 45 60 120)
  reported_minutes=$(printf '%s\n' "${minutes[@]}" | fzf --layout=reverse)
  echo "Change status response:"
  curl -s -X PUT --location "${GD_URL}/task/${taskId}/status" -H "$GD_HEADER" -H "Content-Type: application/json" -d '{"userId": "'"$GD_USER"'", "statusId": "'"$status_id"'"}'
  echo "Change AR response:"
  curl -s -X POST --location "${GD_URL}/task/${taskId}/reply" -H "$GD_HEADER" -H "Content-Type: application/json" -d '{"userId": "'"$GD_USER"'", "actionRequiredUserId": "'"$ar_user_id"'", "message": "'"$user_reply"'"}'
  echo "Time log response:"
  curl -s -X POST --location "${GD_URL}/task/${taskId}/time-report" -H "$GD_HEADER" -H "Content-Type: application/json" -d '{"userId": "'"$GD_USER"'", "reportedMinutes": "'"$reported_minutes"'"}'
  echo "Check the status in a browser"
  xdg-open "https://www.goodday.work/t/$taskId"
  ;;
*)
  echo "Invalid option: $user_selection"
  ;;
esac
