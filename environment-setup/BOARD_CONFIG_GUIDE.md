# Board Configuration Guide

## Overview

The `meshfox-builder-pico.sh` script now includes a board configuration system that allows you to define board-specific settings in one place. This makes it easy to support multiple target boards and adjust the chroot scripts, kernel versions, and rootfs paths accordingly.

## Current Configuration

The board configuration is defined near the top of the script (after the `sudoer` variable assignment) using a bash associative array:

```bash
declare -A BOARD_CONFIG

# Femtofox configuration
BOARD_CONFIG[femtofox_rootfs_path]="rootfs_uclibc_rv1106"
BOARD_CONFIG[femtofox_kernel_version]="5.10.160"
BOARD_CONFIG[femtofox_chroot_script]="/home/${sudoer}/MeshFox/environment-setup/meshfox-femtofox.chroot"
BOARD_CONFIG[femtofox_defconfig]="femtofox_rv1106_linux_defconfig"

# Luckfox Pico Ultra configuration
BOARD_CONFIG[pico-ultra_rootfs_path]="rootfs_uclibc_rv1106"
BOARD_CONFIG[pico-ultra_kernel_version]="5.10.160"
BOARD_CONFIG[pico-ultra_chroot_script]="/home/${sudoer}/MeshFox/environment-setup/meshfox-pico-ultra.chroot"
BOARD_CONFIG[pico-ultra_defconfig]="luckfox_rv1106_linux_defconfig"

# Default board (can be overridden by command line or environment variable)
TARGET_BOARD="${TARGET_BOARD:-femtofox}"
```

## Usage

### Using the Default Board

By default, the script uses `femtofox`. Simply run:

```bash
sudo ./meshfox-builder-pico.sh full_rebuild
```

### Specifying a Different Board

Use the `--board` flag to specify a target board:

```bash
sudo ./meshfox-builder-pico.sh --board pico-ultra full_rebuild
```

### Overriding the Chroot Script

You can override the board's default chroot script with the `--chroot-script` flag:

```bash
sudo ./meshfox-builder-pico.sh --board femtofox --chroot-script /path/to/custom.chroot full_rebuild
```

Both flags can be combined with any build function.

## Adding a New Board

To add support for a new board (e.g., `pico-mini`):

1. Add the board configuration to the `BOARD_CONFIG` array:

```bash
# Luckfox Pico Mini configuration
BOARD_CONFIG[pico-mini_rootfs_path]="rootfs_uclibc_rv1106"
BOARD_CONFIG[pico-mini_kernel_version]="5.10.160"
BOARD_CONFIG[pico-mini_chroot_script]="/home/${sudoer}/MeshFox/environment-setup/meshfox-pico-mini.chroot"
BOARD_CONFIG[pico-mini_defconfig]="luckfox_rv1106_linux_defconfig"
```

2. Create the board-specific chroot script if needed
3. Use the board:

```bash
sudo ./meshfox-builder-pico.sh --board pico-mini sdk_install
```

## Configuration Parameters

Each board has the following parameters:

- **`{board}_rootfs_path`**: The path to the rootfs directory (relative to `/home/${sudoer}/luckfox-pico/sysdrv/out/`)
- **`{board}_kernel_version`**: The kernel version being used (e.g., `5.10.160`)
- **`{board}_chroot_script`**: The path to the board-specific chroot setup script
- **`{board}_defconfig`**: The kernel defconfig name for this board

## Helper Function

The script includes a helper function `get_board_config()` that retrieves board-specific values:

```bash
local kernel_version=$(get_board_config kernel_version)
local rootfs_path=$(get_board_config rootfs_path)
```

This function automatically prefixes the parameter name with the `TARGET_BOARD` name to look up the correct configuration value.

## Environment Variables

You can also set the target board via an environment variable:

```bash
export TARGET_BOARD=pico-ultra
sudo ./meshfox-builder-pico.sh full_rebuild
```

Command-line `--board` flags will override environment variables.

## Available Boards

Currently configured boards:
- **`femtofox`** (default) — Femtofox board configuration
- **`pico-ultra`** — Luckfox Pico Ultra configuration
