# MeshFox

MeshFox is an Ubuntu-based Linux distribution for Luckfox boards equipped with LoRa radios. It extends the excellent [Foxbuntu](https://github.com/femtofox/femtofox) work by Femtofox to provide Ubuntu builds for a number of Luckfox based deployed for Meshcore.

## Supported Boards

- **Femtofox** - [Luckfox Pico Mini with LoRa](https://github.com/femtofox/femtofox)
- **Luckfox Pico Ultra** - Larger variant with more processing power

## Quick Start

### Prerequisites
- Ubuntu 22.04 (WSL2 or native)
- Root/sudo access
- ~100GB free disk space for builds

### Installation

```bash
cd environment-setup
sudo ./meshfox-builder-pico.sh --board femtofox sdk_install
```

For Pico Ultra:
```bash
sudo ./meshfox-builder-pico.sh --board pico-ultra sdk_install
```

## Features

- **Multi-board support** - Configure build settings per target hardware
- **Automated build system** - Script-based environment setup and image creation
- **LoRa integration** - Pre-configured for LoRa radio communication
- **Ubuntu base** - Familiar Linux distribution with package management

## Usage

### Build a Complete Image
```bash
sudo ./meshfox-builder-pico.sh --board femtofox full_rebuild
```

### Update Existing Build
```bash
sudo ./meshfox-builder-pico.sh --board femtofox update_image
```

### Modify Kernel
```bash
sudo ./meshfox-builder-pico.sh --board femtofox modify_kernel
```

### Custom Chroot Script
```bash
sudo ./meshfox-builder-pico.sh --board femtofox --chroot-script /path/to/script.chroot rebuild_chroot
```

For more options, see [BOARD_CONFIG_GUIDE.md](environment-setup/BOARD_CONFIG_GUIDE.md).

## Documentation

- **[BOARD_CONFIG_GUIDE.md](environment-setup/BOARD_CONFIG_GUIDE.md)** - Board configuration and customization
- **[meshfox-builder-pico.sh](environment-setup/meshfox-builder-pico.sh)** - Build script with all available functions

## Roadmap

- [ ] Complete pyMC_Repeater integration
- [ ] Support for Luckfox Lyra boards
- [ ] Support for Luckfox Core3506 boards  
- [ ] Automated multi-board CI/CD pipeline

## Related Projects

- [Femtofox](https://github.com/femtofox/femtofox) - Original LoRa distribution for Luckfox
- [pyMC_Repeater](https://github.com/pymc-repeater) - Mesh network repeater software

## License

See [LICENSE](LICENSE) file for details.
