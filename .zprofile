# Auto-export all variables from .env
if [ -f ~/.env ]; then
  export $(grep -v '^#' ~/.env | xargs)
fi
