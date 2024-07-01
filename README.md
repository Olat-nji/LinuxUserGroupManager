# User and Group Management Script

## Overview

This script automates the creation of users and groups based on the contents of a specified file. It logs all actions performed and stores user passwords securely. The script includes error handling for existing users and groups and ensures proper permissions are set on sensitive files.

## Requirements

- The script must be run as root.
- A text file with the format: `username; group1,group2,...` for each line.

## Usage

```bash
sudo ./create_users.sh <filename>
