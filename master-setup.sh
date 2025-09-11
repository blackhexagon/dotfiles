#!/bin/bash

# Master Setup Script for Dotfiles
# Automates the execution of all setup scripts in the correct order

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="$SCRIPT_DIR/scripts"
readonly STATE_FILE="$HOME/.dotfiles-setup-state"
readonly LOG_FILE="$HOME/.dotfiles-setup.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script execution phases and their scripts
declare -A PHASES=(
    ["foundation"]="essential-installs.sh zsh.sh"
    ["shell-config"]="zsh-plugins.sh font.sh"
    ["dev-tools"]="nvm.sh github.sh neovim.sh docker.sh docker-post-install.sh"
    ["config"]="tmux.sh dotfiles.sh"
    ["customization"]="keyboard.sh"
    ["optional"]="bat.sh gcloud.sh phpactor.sh ddev.sh aicommits.sh style-gnome-terminal.sh"
)

# Critical scripts that must succeed
declare -A CRITICAL_SCRIPTS=(
    ["essential-installs.sh"]=1
    ["zsh.sh"]=1
    ["docker.sh"]=1
)

# Interactive scripts requiring user input
declare -A INTERACTIVE_SCRIPTS=(
    ["github.sh"]=1
    ["keyboard.sh"]=1
    ["dotfiles.sh"]=1
)

# Scripts that trigger shell restart requirement
declare -A RESTART_TRIGGERS=(
    ["zsh.sh"]=1
)

# Global options
UNATTENDED=false
DRY_RUN=false
RESUME=false
PHASE_ONLY=""
VERBOSE=false

# Utility functions
log() {
    echo -e "${1}" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

show_progress() {
    local current=$1
    local total=$2
    local script=$3
    local percent=$((current * 100 / total))
    log_info "Progress: [$current/$total] ($percent%) - Running: $script"
}

# State management functions
save_state() {
    local phase=$1
    local script=$2
    local status=$3
    echo "$phase:$script:$status:$(date +%s)" >> "$STATE_FILE"
}

load_state() {
    [[ -f "$STATE_FILE" ]] || return 1
    cat "$STATE_FILE"
}

is_script_completed() {
    local script=$1
    [[ -f "$STATE_FILE" ]] || return 1
    grep -q ":$script:completed:" "$STATE_FILE"
}

get_last_phase() {
    [[ -f "$STATE_FILE" ]] || return 1
    tail -n 1 "$STATE_FILE" | cut -d: -f1
}

needs_shell_restart() {
    [[ -f "$STATE_FILE" ]] || return 1
    grep -q ":zsh.sh:completed:" "$STATE_FILE" && ! grep -q "shell_restarted" "$STATE_FILE"
}

mark_shell_restarted() {
    echo "shell_restarted:$(date +%s)" >> "$STATE_FILE"
}

# Pre-flight checks
check_dependencies() {
    local missing_deps=()
    
    command -v bash >/dev/null 2>&1 || missing_deps+=("bash")
    command -v wget >/dev/null 2>&1 || missing_deps+=("wget")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
}

check_script_exists() {
    local script=$1
    if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
        log_warning "Script not found: $script"
        return 1
    fi
    if [[ ! -x "$SCRIPTS_DIR/$script" ]]; then
        log_warning "Script not executable: $script"
        chmod +x "$SCRIPTS_DIR/$script"
    fi
    return 0
}

# Script execution functions
run_script() {
    local script=$1
    local phase=$2
    
    if is_script_completed "$script"; then
        log_info "Skipping already completed: $script"
        return 0
    fi
    
    if ! check_script_exists "$script"; then
        save_state "$phase" "$script" "missing"
        return 1
    fi
    
    # Handle interactive scripts in unattended mode
    if [[ "$UNATTENDED" == "true" && -n "${INTERACTIVE_SCRIPTS[$script]:-}" ]]; then
        log_warning "Skipping interactive script in unattended mode: $script"
        save_state "$phase" "$script" "skipped"
        return 0
    fi
    
    # Prompt for interactive scripts
    if [[ -n "${INTERACTIVE_SCRIPTS[$script]:-}" && "$UNATTENDED" != "true" ]]; then
        echo
        log_warning "The script '$script' requires user interaction."
        read -p "Do you want to run it now? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping $script (user choice)"
            save_state "$phase" "$script" "skipped"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $script"
        return 0
    fi
    
    log_info "Executing: $script"
    save_state "$phase" "$script" "running"
    
    local start_time=$(date +%s)
    if "$SCRIPTS_DIR/$script" 2>&1 | tee -a "$LOG_FILE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        save_state "$phase" "$script" "completed"
        log_success "Completed: $script (${duration}s)"
        
        # Check if this script requires shell restart
        if [[ -n "${RESTART_TRIGGERS[$script]:-}" ]]; then
            handle_shell_restart
        fi
        
        return 0
    else
        local exit_code=$?
        save_state "$phase" "$script" "failed"
        log_error "Failed: $script (exit code: $exit_code)"
        
        # Handle critical script failures
        if [[ -n "${CRITICAL_SCRIPTS[$script]:-}" ]]; then
            log_error "Critical script failed. Setup cannot continue."
            return $exit_code
        fi
        
        # Offer retry for non-critical scripts
        if [[ "$UNATTENDED" != "true" ]]; then
            echo
            read -p "Script failed. Retry? [y/N]: " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Retrying: $script"
                run_script "$script" "$phase"
                return $?
            fi
        fi
        
        log_warning "Continuing despite failure of non-critical script: $script"
        return 0
    fi
}

handle_shell_restart() {
    echo
    log_warning "Shell restart required after zsh installation!"
    log_info "Please follow these steps:"
    log_info "1. Close this terminal"
    log_info "2. Open a new terminal"
    log_info "3. Navigate to: $SCRIPT_DIR"
    log_info "4. Run: ./master-setup.sh --resume"
    echo
    log_info "Setup state has been saved. You can safely resume from where you left off."
    exit 0
}

run_phase() {
    local phase_name=$1
    local scripts=(${PHASES[$phase_name]})
    local total_scripts=${#scripts[@]}
    local current=0
    
    log_info "Starting phase: $phase_name"
    
    for script in "${scripts[@]}"; do
        ((current++))
        show_progress "$current" "$total_scripts" "$script"
        
        if ! run_script "$script" "$phase_name"; then
            if [[ -n "${CRITICAL_SCRIPTS[$script]:-}" ]]; then
                log_error "Critical failure in phase: $phase_name"
                return 1
            fi
        fi
    done
    
    log_success "Completed phase: $phase_name"
    return 0
}

# Main execution function
run_setup() {
    local start_phase=""
    
    if [[ "$RESUME" == "true" ]]; then
        if needs_shell_restart; then
            mark_shell_restarted
            log_info "Detected shell restart. Resuming setup..."
        fi
        
        start_phase=$(get_last_phase) || start_phase=""
        if [[ -n "$start_phase" ]]; then
            log_info "Resuming from phase: $start_phase"
        fi
    fi
    
    local phases_to_run=()
    if [[ -n "$PHASE_ONLY" ]]; then
        phases_to_run=("$PHASE_ONLY")
    else
        phases_to_run=("foundation" "shell-config" "dev-tools" "config" "customization" "optional")
    fi
    
    local start_found=false
    if [[ -z "$start_phase" ]]; then
        start_found=true
    fi
    
    for phase in "${phases_to_run[@]}"; do
        if [[ "$start_found" == "false" ]]; then
            if [[ "$phase" == "$start_phase" ]]; then
                start_found=true
            else
                continue
            fi
        fi
        
        if ! run_phase "$phase"; then
            log_error "Setup failed in phase: $phase"
            return 1
        fi
    done
    
    return 0
}

show_summary() {
    echo
    log_info "=== SETUP SUMMARY ==="
    
    if [[ ! -f "$STATE_FILE" ]]; then
        log_info "No setup state found."
        return
    fi
    
    local completed=0
    local failed=0
    local skipped=0
    
    while IFS=':' read -r phase script status timestamp; do
        case "$status" in
            completed) ((completed++)) ;;
            failed) ((failed++)) ;;
            skipped) ((skipped++)) ;;
        esac
    done < "$STATE_FILE"
    
    log_success "Completed: $completed scripts"
    [[ $failed -gt 0 ]] && log_error "Failed: $failed scripts"
    [[ $skipped -gt 0 ]] && log_warning "Skipped: $skipped scripts"
    
    echo
    log_info "Detailed log available at: $LOG_FILE"
    
    if [[ $failed -eq 0 ]]; then
        log_success "🎉 Setup completed successfully!"
        log_info "You may need to restart your terminal or log out/in for all changes to take effect."
    fi
}

show_help() {
    cat << EOF
Master Setup Script for Dotfiles

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -u, --unattended    Run in unattended mode (skip interactive scripts)
    -d, --dry-run       Show what would be executed without running
    -r, --resume        Resume setup after shell restart
    -p, --phase PHASE   Run only specific phase
    -v, --verbose       Enable verbose output
    --reset             Reset setup state and start fresh

PHASES:
    foundation      System foundation (essential packages, zsh)
    shell-config    Shell configuration (plugins, fonts)
    dev-tools       Development tools (nvm, github, docker, neovim)
    config          Configuration (tmux, dotfiles)
    customization   System customization (keyboard)
    optional        Optional tools (bat, gcloud, etc.)

EXAMPLES:
    $0                          # Interactive setup
    $0 --unattended             # Automated setup
    $0 --phase dev-tools        # Install only development tools
    $0 --resume                 # Resume after shell restart
    $0 --dry-run                # Preview what would be executed

EOF
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--unattended)
            UNATTENDED=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -r|--resume)
            RESUME=true
            shift
            ;;
        -p|--phase)
            PHASE_ONLY="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --reset)
            rm -f "$STATE_FILE" "$LOG_FILE"
            log_info "Setup state reset."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Initialize log
    echo "=== Dotfiles Master Setup Started: $(date) ===" > "$LOG_FILE"
    
    log_info "Starting dotfiles setup..."
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Log file: $LOG_FILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    if [[ "$UNATTENDED" == "true" ]]; then
        log_info "UNATTENDED MODE - Interactive scripts will be skipped"
    fi
    
    # Validate phase if specified
    if [[ -n "$PHASE_ONLY" && -z "${PHASES[$PHASE_ONLY]:-}" ]]; then
        log_error "Invalid phase: $PHASE_ONLY"
        log_info "Available phases: ${!PHASES[*]}"
        exit 1
    fi
    
    check_dependencies
    
    if run_setup; then
        show_summary
        exit 0
    else
        show_summary
        exit 1
    fi
}

# Execute main function
main "$@"