# Stinos-FTP-Downloader
Simple FTP downloader with schedule and database. Runs in a Docker container.


> [!WARNING]
> **SSL verification is DISABLED** at the moment! This project is still under development. It will be added later.

### 1. Configure environment

1.1. Copy the example environment config file:

```bash
cp .env.example .env
```

1.2. Edit the .env file with your settings.

```bash
nano .env
```

### 2. Start container

2.1 Navigate to the root of the project and start with:

```bash
docker-compose up -d
```
