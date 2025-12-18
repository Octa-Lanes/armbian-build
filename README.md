> **This repository is used exclusively to build the Octimus-I system image by Octalanes.**  
> It is not intended for general-purpose Armbian image builds.

## Repository Scope

**This repository:**
- Builds the official **Octimus-I production OS image**
- Includes Octimus-I specific kernel patches, device trees, and resources

**This repository does NOT:**
- Document end-user device setup (available in internal Confluence documentation)
- Provide application-level deployment guides (available in internal Confluence documentation)

## Purpose — Octimus-I Image Build System

The **Armbian Linux Build Framework** based on **Debian** or **Ubuntu**,
customized specifically for **Octimus-I** by **Octalanes**.

The toolchain builds a fully customized system image, including:

- Custom Linux kernel
- Bootloader selection and customization
- Root filesystem generation
- Filesystem layout and compression
- Additional drivers, overlays, and device trees

## Getting started

Clone the repository:
```bash
git clone git@github.com:Octa-Lanes/armbian-build.git
```

Enter the build directory:
```bash
cd build
```

### User-Data Partition (Required)

Before building an Octimus-I image, a prebuilt SVT application archive named: user-data.tar.gz is required.

The file must be placed at:
```bash
build/octimus-i-resources/user-data.tar.gz
```

Download the archive from:
```bash
https://8lanes.sgp1.digitaloceanspaces.com/hope-resource/user-data.tar.gz
```

### Build Options

Build Using Armbian Interactive UI
```bash
./compile.sh
```

Build CLI Armbian Noble (GNOME) for Octimus-I
```bash
./compile.sh build BOARD=radxa-cm4-io BRANCH=vendor BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED=' ' DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base KERNEL_CONFIGURE=no RELEASE=noble
```

### Output Image File

After a successful build, the generated OS image will be available at:
```bash
build/output/image/
```

## Build Host Requirements

- **Supported Architectures:** `x86_64`, `aarch64`, `riscv64`
- **System:** VM, container, or bare-metal with:
  - **≥ 8GB RAM** (less with `KERNEL_BTF=no`)
  - **~50GB disk space**
- **Operating System:**
  - Armbian / Ubuntu 24.04 (Noble) for native builds
  - Any Docker-capable Linux for containerized setup
- **Windows:** Windows 10/11 with WSL2 running Armbian / Ubuntu 24.04
- **Access:** Superuser rights (`sudo` or `root`)
- **Important:** Keep your system up-to-date — outdated tools (e.g., Docker) can cause issues.
