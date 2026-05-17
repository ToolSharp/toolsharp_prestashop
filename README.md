# ToolSharp — PrestaShop Modules

A collection of PrestaShop 8 modules built and maintained by ToolSharp.

## Repository structure

```
toolsharp-prestashop/
├── modules/                          # One subdirectory per module
│   └── toolsharp_productdiscounts/
├── scripts/
│   ├── build.sh                      # Package module(s) into zip(s)
│   ├── deploy.sh                     # Deploy to a configured environment
│   └── watch.sh                      # Auto-deploy on file change (dev)
├── config/
│   ├── environments.example.sh       # Template — copy to environments.sh
│   └── environments.sh               # Your credentials (gitignored)
├── dist/                             # Built zips (gitignored)
└── .github/workflows/release.yml     # Auto-release on version tag
```

## First-time setup

```bash
# 1. Clone the repo
git clone https://github.com/your-org/toolsharp-prestashop.git
cd toolsharp-prestashop

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Create your environments config
cp config/environments.example.sh config/environments.sh
# Edit config/environments.sh with your server details

# 4. (Optional) Install fswatch for the watch script
brew install fswatch
```

## Scripts

### build.sh — Package modules

```bash
# Build all modules
./scripts/build.sh

# Build a specific module
./scripts/build.sh toolsharp_productdiscounts

# Build with a version number in the filename
./scripts/build.sh --version 1.2.0 toolsharp_productdiscounts
# → dist/toolsharp_productdiscounts-1.2.0.zip
```

### deploy.sh — Deploy to an environment

Environments and their connection details are defined in `config/environments.sh`.
Three deployment methods are supported: `rsync` (SSH), `ftp`, and `zip` (manual upload).

```bash
# Deploy a specific module to dev
./scripts/deploy.sh --env dev_docker --module toolsharp_productdiscounts

# Deploy all modules to staging
./scripts/deploy.sh --env staging

# Build then deploy in one step
./scripts/deploy.sh --env dev_docker --module toolsharp_productdiscounts --build
```

### watch.sh — Auto-deploy on change

Watches the module source directory with `fswatch` and re-deploys on every save.
Ideal for developing against a remote Docker container.

```bash
./scripts/watch.sh --env dev_docker --module toolsharp_productdiscounts
```

## Releasing a new version

Push a version tag and GitHub Actions will build all module zips and attach
them to a GitHub Release automatically:

```bash
git tag v1.2.0
git push --tags
```

Pre-release tags (e.g. `v1.2.0-beta`, `v1.2.0-rc1`) are automatically marked
as pre-releases on GitHub.

## Modules

| Module | Description | Version |
|--------|-------------|---------|
| [toolsharp_productdiscounts](modules/toolsharp_productdiscounts/) | Displays valid discount codes on the product page | 1.0.0 |