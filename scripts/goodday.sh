#!/bin/bash

# Load text formatting.
# source $HOME/scripts/text.sh

GD_HEADER="gd-api-token: $GOODDAY_TOKEN"
GD_USER="$GOODDAY_USER"
GD_URL="https://api.goodday.work/2.0"

function getId() {
  echo "$1" | grep -oP '\(\K[^()]*' | tail -1
}

function fetchTasksWithProject() {
  local tasks=$(curl -s -H "$GD_HEADER" $GD_URL/user/$GD_USER/action-required-tasks)
  local projects=$(curl -s -H "$GD_HEADER" $GD_URL/projects)
  jq --argjson tasks "$tasks" --argjson projects "$projects" -n \
    '
      [
        ($tasks[] as $t  | select($t.status.name as $status_name | ["On hold", "Completed", "Dlouhodobý"] | index($status_name) | not) |
        $projects[] as $p | select($p.id == $t.projectId) | {task_id: $t.id, task_name: $t.name, status_name: $t.status.name, project_name: $p.name, date: $t.recentActivityMoment})
      ]
      | sort_by(.date) | reverse
      | .[] | "[\(.date[8:10]).\(.date[5:7]) \(.date[11:16])] [\(.project_name)] \(.task_name) (\(.task_id))"
      '
}

function fetchMessagesWithUser() {
  local messages=$(curl -s -H "$GD_HEADER" $GD_URL/task/$1/messages)
  local users=$(curl -s -H "$GD_HEADER" $GD_URL/users)
  jq --argjson messages "$messages" --argjson users "$users" -n \
    '
      [
        ($messages[] as $m | $users[] as $u | select($u.id == $m.fromUserId) | {text: $m.message, date: "\($m.dateCreated[8:10]).\($m.dateCreated[5:7]) \($m.dateCreated[11:16])", user: $u.name})
      ]
      '
}

task=$(fetchTasksWithProject | fzf --layout=reverse)
taskId=$(getId "$task")
echo "$taskId"

echo "What you want to do:"
options=("Reply" "Detail" "Open")
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
