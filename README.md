# How to use

To get the list of available commands, run:

```bash
 make help
```

Check your environment is correctly set for the target environment:

```bash
make check_env ENV=binance
```

If you want to bootstrap the environment and apply the configuration.
Note that you need to have kubectl configured with the right context.

```bash
make bootstrap ENV=binance
```

# Environment's folder structure

Each environment is defined by a folder in the root directory.

The folder structure is the following:

```bash
├── common # Common resources for all environments
├── flux-system # Flux system resources
├── helm # Helm resources
├── apps # Application resources
```
