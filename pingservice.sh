#!/bin/bash

# Ping Service Management Script (pingservice) - Single File Version
# Allows listing, adding, deleting, and checking status/logs of continuous-ping services.

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# --- Helper Functions ---

# Function to log messages (used internally by this script)
_log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
_log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
_log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
_log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
_log_command() { echo -e "  ${CYAN}➔ $1${NC}"; } # For displaying example commands

# Function to check if running as root
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    _log_error "This script must be run as root (sudo)."
    exit 1
  fi
}

# --- Service Creation Logic (Moved Inline) ---
_perform_service_creation() {
  local target_ip="$1"
  if [ -z "$target_ip" ]; then
    _log_error "Target IP cannot be empty for service creation."
    return 1
  fi

  _log_info "Starting creation process for IP: ${YELLOW}${target_ip}${NC}"

  local sanitized_ip
  sanitized_ip=$(echo "${target_ip}" | sed 's/[:.]/-/g')
  local service_name="continuous-ping-${sanitized_ip}.service"
  local service_file_path="/etc/systemd/system/${service_name}"

  _log_info "Service name will be: ${YELLOW}${service_name}${NC}"
  _log_info "Service file will be at: ${YELLOW}${service_file_path}${NC}"

  local service_content="[Unit]
Description=Continuous Ping Service for ${target_ip}
After=network.target

[Service]
ExecStart=/bin/ping \"${target_ip}\"
Restart=always
RestartSec=10s
# User=nobody
# Group=nogroup

[Install]
WantedBy=multi-user.target
"
  _log_info "Writing service file..."
  echo "${service_content}" > "${service_file_path}"
  if [ $? -ne 0 ]; then
      _log_error "Failed to write service file to ${service_file_path}."
      return 1
  fi
  _log_success "Service file written."

  _log_info "Reloading systemd daemon..."
  systemctl daemon-reload
  if [ $? -ne 0 ]; then _log_error "Failed to reload systemd daemon."; return 1; fi
  _log_success "Systemd daemon reloaded."

  _log_info "Enabling service ${YELLOW}${service_name}${NC} for auto-start..."
  systemctl enable "${service_name}"
  if [ $? -ne 0 ]; then
      _log_error "Failed to enable service ${service_name}."
      _log_warning "Attempting to clean up the service file: ${service_file_path}"
      rm -f "${service_file_path}"
      systemctl daemon-reload
      return 1
  fi
  _log_success "Service enabled."

  _log_info "Starting/Restarting service ${YELLOW}${service_name}${NC}..."
  systemctl restart "${service_name}"
  if [ $? -ne 0 ]; then
      _log_error "Failed to start/restart service ${service_name}."
      echo -e "${YELLOW}You can check the status with:${NC}"
      _log_command "sudo systemctl status ${service_name}"
      echo -e "${YELLOW}And logs with:${NC}"
      _log_command "sudo journalctl -u ${service_name}"
      _log_warning "Attempting to disable and clean up if start fails..."
      systemctl disable "${service_name}" --now >/dev/null 2>&1
      rm -f "${service_file_path}"
      systemctl daemon-reload
      return 1
  fi
  _log_success "Service started/restarted."

  echo -e "${BLUE}--------------------------------------------------${NC}"
  _log_success "Service '${YELLOW}${service_name}${NC}' for IP '${YELLOW}${target_ip}${NC}' created and activated."
  _log_info "It will also start automatically on system boot."
  echo -e "${BLUE}--------------------------------------------------${NC}"
  echo -e "${YELLOW}Useful commands for this service:${NC}"
  echo -e "  To check status:   "; _log_command "sudo systemctl status ${service_name}"
  echo -e "  To view live logs: "; _log_command "sudo journalctl -u ${service_name} -f"
  return 0
}


# Function to list existing continuous-ping services
list_ping_services() {
  echo -e "${MAGENTA}--- Available Continuous Ping Services ---${NC}"
  local services
  services=$(systemctl list-unit-files --type=service --all | grep 'continuous-ping-.*\.service' | awk '{print $1}')
  if [ -z "$services" ]; then
    _log_warning "No continuous-ping services found."
    return 1
  fi
  
  local i=1
  local service_array=()
  local OLD_IFS="$IFS"
  IFS=$'\n'
  for service_name in $services; do
    if [[ -n "$service_name" ]]; then
      local ip_part="${service_name#continuous-ping-}"
      ip_part="${ip_part%.service}"
      ip_part=$(echo "$ip_part" | sed 's/\([0-9a-fA-F]\)-\([0-9a-fA-F]\)/\1.\2/g; s/--/:/g') # Basic IP reversal

      local status_text
      if systemctl is-active --quiet "$service_name"; then
        status_text="${GREEN}active${NC}"
      else
        status_text="${RED}inactive${NC}"
      fi

      local enabled_text
      if systemctl is-enabled --quiet "$service_name"; then
        enabled_text="${GREEN}enabled${NC}"
      else
        enabled_text="${RED}disabled${NC}"
      fi
      
      printf "  ${YELLOW}%2d.${NC} ${CYAN}%-40s${NC} (IP: ${YELLOW}%-30s${NC} Status: %-18s Enabled: %s)\n" \
             "$i" "$service_name" "$ip_part" "$status_text" "$enabled_text"
      service_array+=("$service_name")
      i=$((i+1))
    fi
  done
  IFS="$OLD_IFS"
  
  declare -g PING_SERVICE_ARRAY=("${service_array[@]}")
  if [ ${#PING_SERVICE_ARRAY[@]} -eq 0 ]; then
      _log_warning "No continuous-ping services found after processing."
      return 1
  fi
  return 0
}

# Function to add a new ping service
add_service() {
  echo -e -n "${BLUE}Enter the IP address to ping continuously: ${YELLOW}"
  read -r target_ip
  echo -e "${NC}"
  if [ -z "$target_ip" ]; then
    _log_warning "No IP address entered. Aborting."
    return
  fi

  # Call the internal function to create the service
  _perform_service_creation "$target_ip"
}

# Function to delete a ping service
delete_service() {
  list_ping_services
  if [ ${#PING_SERVICE_ARRAY[@]} -eq 0 ]; then return; fi

  echo -e -n "${BLUE}Enter the number of the service to delete: ${YELLOW}"
  read -r choice
  echo -e "${NC}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#PING_SERVICE_ARRAY[@]} ]; then
    _log_error "Invalid choice. Aborting."
    return
  fi

  local service_to_delete="${PING_SERVICE_ARRAY[$((choice-1))]}"
  echo -e -n "${RED}Are you sure you want to delete service '${YELLOW}${service_to_delete}${RED}'? (yes/no): ${YELLOW}"
  read -r confirmation
  echo -e "${NC}"
  if [ "$confirmation" != "yes" ]; then
    _log_info "Deletion aborted."
    return
  fi

  _log_info "Stopping service ${YELLOW}${service_to_delete}${NC}..."
  systemctl stop "$service_to_delete"
  _log_info "Disabling service ${YELLOW}${service_to_delete}${NC}..."
  systemctl disable "$service_to_delete"
  local service_file_path="/etc/systemd/system/${service_to_delete}"
  _log_info "Removing service file ${YELLOW}${service_file_path}${NC}..."
  rm -f "$service_file_path"
  _log_info "Reloading systemd daemon..."
  systemctl daemon-reload
  _log_success "Service '${YELLOW}${service_to_delete}${NC}' deleted successfully."
}

# Function to view logs of a service
view_logs() {
  list_ping_services
  if [ ${#PING_SERVICE_ARRAY[@]} -eq 0 ]; then return; fi

  echo -e -n "${BLUE}Enter the number of the service to view logs for: ${YELLOW}"
  read -r choice
  echo -e "${NC}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#PING_SERVICE_ARRAY[@]} ]; then
    _log_error "Invalid choice. Aborting."
    return
  fi
  local service_to_log="${PING_SERVICE_ARRAY[$((choice-1))]}"
  _log_info "Showing live logs for ${YELLOW}${service_to_log}${NC}. Press ${RED}Ctrl+C${NC} to exit."
  journalctl -u "$service_to_log" -f
}

# Function to view status of a service
view_status() {
  list_ping_services
  if [ ${#PING_SERVICE_ARRAY[@]} -eq 0 ]; then return; fi

  echo -e -n "${BLUE}Enter the number of the service to view status for: ${YELLOW}"
  read -r choice
  echo -e "${NC}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#PING_SERVICE_ARRAY[@]} ]; then
    _log_error "Invalid choice. Aborting."
    return
  fi
  local service_to_status="${PING_SERVICE_ARRAY[$((choice-1))]}"
  _log_info "Status for ${YELLOW}${service_to_status}${NC}:"
  systemctl status "$service_to_status"
}

# Function to guide user on editing a service
edit_service_guidance() {
  list_ping_services
  if [ ${#PING_SERVICE_ARRAY[@]} -eq 0 ]; then return; fi

  echo -e -n "${BLUE}Enter the number of the service file you want to edit: ${YELLOW}"
  read -r choice
  echo -e "${NC}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#PING_SERVICE_ARRAY[@]} ]; then
    _log_error "Invalid choice. Aborting."
    return
  fi
  local service_to_edit="${PING_SERVICE_ARRAY[$((choice-1))]}"
  local service_file_path="/etc/systemd/system/${service_to_edit}"

  echo -e "${MAGENTA}--- How to Edit Service '${YELLOW}${service_to_edit}${MAGENTA}' ---${NC}"
  echo -e "1. Open the service file with a text editor (e.g., nano, vim):"
  _log_command "sudo nano ${service_file_path}"
  echo -e "2. Make your desired changes (e.g., the IP address in ${YELLOW}ExecStart=/bin/ping \"<NEW_IP>\"${NC})."
  echo -e "3. Save the file and exit the editor."
  echo -e "4. Reload the systemd daemon to apply changes to systemd's internal state:"
  _log_command "sudo systemctl daemon-reload"
  echo -e "5. Restart the service for the changes to take effect on the running process:"
  _log_command "sudo systemctl restart ${service_to_edit}"
  echo -e "${MAGENTA}-------------------------------------------${NC}"
}


# --- Main Menu ---
main_menu() {
  while true; do
    # clear # Optional: Clears the screen for the next menu display
    echo ""
    echo -e "${MAGENTA}========== Ping Service Manager ==========${NC}"
    echo -e "${BLUE}  1.${NC} ${CYAN}List Ping Services${NC}"
    echo -e "${BLUE}  2.${NC} ${GREEN}Add New Ping Service${NC}"
    echo -e "${BLUE}  3.${NC} ${RED}Delete Ping Service${NC}"
    echo -e "${BLUE}  4.${NC} ${YELLOW}View Service Logs (Live)${NC}"
    echo -e "${BLUE}  5.${NC} ${YELLOW}View Service Status${NC}"
    echo -e "${BLUE}  6.${NC} ${CYAN}Edit Service (Show Guidance)${NC}"
    echo -e "${BLUE}  0.${NC} ${MAGENTA}Exit${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo -e -n "${BLUE}Enter your choice: ${YELLOW}"
    read -r main_choice
    echo -e "${NC}" # Reset color

    case $main_choice in
      1) list_ping_services ;;
      2) add_service ;;
      3) delete_service ;;
      4) view_logs ;;
      5) view_status ;;
      6) edit_service_guidance ;;
      0) _log_info "Exiting."; exit 0 ;;
      *) _log_error "Invalid option. Please try again." ;;
    esac
    echo ""
    echo -e -n "${BLUE}Press Enter to continue...${NC}"
    read -r
  done
}

# --- Script Execution ---
check_root
main_menu
