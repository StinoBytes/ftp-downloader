# Stino's FTP Downloader
Simple FTP downloader with schedule and database. Runs in a Docker container.


> [!WARNING]
> **SSL verification is DISABLED** at the moment! This project is still under development. It will be added later. Use at your own risk.

This project is meant to download large quantities of data from an FTP server.

- You will be able to move finished downloads from the `finished` folder. The database keeps track of what has been downloaded already, even if the container is stopped and restarted, updated, or even removed and reinstalled as long as the database remains untouched.
- If your internet provider has a fair use policy (FUP), you can set certain hours in which it will download. In the other hours it will not download anything, avoiding going over the limit of your FUP.

If you encounter any problems or have suggestions, create an issue.

## Usage:

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
