dev() {
  tmux split-window -h -l 67% \; \
    split-window -v -l 25% \; \
    send-keys -t 1 'opencode --port' Enter \; \
    send-keys -t 2 'nvim .' Enter \; \
    send-keys -t 3 'git status' Enter \; \
    select-pane -t 2
}

# Split tmux window into thirds
thirds() {
  tmux split-window -h \; \
    select-pane -R \; \
    split-window -h \; \
    select-layout even-horizontal
}
