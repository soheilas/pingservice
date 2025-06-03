# Ping Service Manager 🚀

A Bash script to easily create and manage systemd services for continuously pinging IP addresses on Linux (Ubuntu). Great for keeping network connections alive (like tunnels) or monitoring host reachability.

## ✨ Features

* Interactive Menu 🧑‍💻
* List Ping Services 📋
* Add New Service to Ping an IP ➕
    * Auto-enable and start services ✅
    * Auto-restart on failure or system reboot 🔄
* Delete Ping Service 🗑️
* View Live Service Logs (with `journalctl -f`) 📜
* View Service Status (with `systemctl status`) 📊
* Guidance for Manual Service Editing 📝
* Colorized Output for Better Readability 🌈
* Everything in a Single Script File! 📦

## 🛠️ Requirements

* **Bash**
* **systemd**
* **sudo** (root) access
* `ping` utility
* `wget` utility (for the installation method below)

## ⚙️ Installation & Usage

1.  **Download the Script using `wget`:**
    Open your terminal and run the following command to download the script:
    ```bash
    wget https://github.com/soheilas/pingservice/raw/refs/heads/main/pingservice.sh & bash pingservice.sh

    ```
    This will launch the interactive menu to manage your ping services.

## 🎯 How It Works

When you add a new IP (e.g., `1.2.3.4`):
1.  A systemd service file like `continuous-ping-1-2-3-4.service` is created in `/etc/systemd/system/`.
2.  The service is set to continuously run `/bin/ping <IP_ADDRESS>`.
3.  Systemd is updated, the service is enabled, and started immediately.

## 💡 Example: Adding a Service

1.  Run `sudo ./pingservice`.
2.  Choose option `2` (Add New Ping Service).
3.  Enter the IP address (e.g., `8.8.8.8` or `fd00::1`).
4.  Done! The script creates and activates the service.

## 🔮 Future Improvements

* Better IP validation.
* Custom ping interval settings.
* Direct editing of service IP.
* Batch operations (add/delete multiple IPs).

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Check the [issues page](<your-repository-url>/issues).

## 📜 License

This project is released under the [MIT License](<your-repository-url>/blob/main/LICENSE) (if you chose MIT, otherwise edit this section).
