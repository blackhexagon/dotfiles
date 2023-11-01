#!/bin/bash
GD_HEADER="gd-api-token: $GOODDAY_TOKEN"
GD_USER="$GOODDAY_USER"
GD_URL="https://api.goodday.work/2.0"

function getId() {
    echo "$1" | grep -oP '\(\K[^()]*' | tail -1
}

function fetchTasksWithProject() {
  local tasks=$( curl -s -H "$GD_HEADER" $GD_URL/user/$GD_USER/action-required-tasks )
  local projects=$( curl -s -H "$GD_HEADER" $GD_URL/projects )
  jq -n --argjson tasks "$tasks" --argjson projects "$projects" \
    '$tasks[] as $t | ($projects[] | select(.id == $t.projectId).name) as $p | "[\($t.status.name)] [\($p)] \($t.name) (\($t.id))"'
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
        url="https://www.goodday.work/t/$taskId"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        xdg-open "$url"
	    elif [[ "$OSTYPE" == "darwin"* ]]; then
	        # Mac OSX
	        open "$url"
	    else
	        echo "Your OS is not supported for this operation."
	    fi
        ;;
	"Detail")
        echo "Opening details..."
        echo $task
        echo "Project: $project_id"
        echo "==========================="
        messages=$( curl -s -H "$GD_HEADER" $GD_URL/task/$taskId/messages )
        length=$(echo "$messages" | jq '. | length')
        for (( i=0; i<$length; i++ ))
        do
          message=$(echo "$messages" | jq -r ".[$i].message")
          date_created=$(echo "$messages" | jq -r ".[$i].dateCreated")
          user_id=$(echo "$messages" | jq -r ".[$i].fromUserId")
            if [[ ! -z "$message" && "$message" != "null" ]]; then
              if [[ "$user_id" == "$GD_USER" ]]; then
                echo "User: Me"
          else
            echo "User: $user_id"
            fi
              echo "Date Created: $date_created"
              echo "$message"
              echo "==========================="
          fi
        done
       ;;
    "Reply")
    	echo "$task"
    	echo "Change status:"
    	statuses=$( curl -s -H "$GD_HEADER" $GD_URL/statuses )
      status=$(echo $statuses | jq -r '.[] | .name + " (" + .id + ")"' | fzf --layout=reverse)
      status_id=$(getId "$status")
      url=
    	echo "Change AR:"
    	users=$( curl -s -H "$GD_HEADER" $GD_URL/users )
		  ar_user=$(echo $users | jq -r '.[] | .name + " (" + .id + ")"' | fzf --layout=reverse)
		  ar_user_id=$(getId "$user")
      echo "Your reply text:"
      read user_reply
      echo "Time report:"
      minutes=(0 5 10 15 30 45 60 120)
      reported_minutes=$(printf '%s\n' "${minutes[@]}" | fzf --layout=reverse)
      echo "Change status response:"
      curl -s -X PUT --location "${GD_URL}/task/${taskId}/status" -H "$GD_HEADER" -H "Content-Type: application/json"  -d '{"userId": "'"$GD_USER"'", "statusId": "'"$status_id"'"}'
      echo "Change AR response:"
      curl -s -X POST --location "${GD_URL}/task/${taskId}/reply" -H "$GD_HEADER" -H "Content-Type: application/json"  -d '{"userId": "'"$GD_USER"'", "actionRequiredUserId": "'"$ar_user_id"'", "message": "'"$user_reply"'"}'
      echo "Time log response:"
      curl -s -X POST --location "${GD_URL}/task/${taskId}/time-report" -H "$GD_HEADER" -H "Content-Type: application/json"  -d '{"userId": "'"$GD_USER"'", "reportedMinutes": "'"$reported_minutes"'"}'
      ;;
    *)
      echo "Invalid option: $user_selection"
      ;;
esac
