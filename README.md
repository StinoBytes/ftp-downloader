# Stino's FTP Downloader

Simple FTP downloader with schedule and database. Runs in a Docker container.

> [!IMPORTANT]
> **Legal Disclaimer:** This tool is intended for downloading legal content only. The author is not responsible for any misuse of this software or for downloading copyrighted material without permission. Users are solely responsible for ensuring compliance with applicable laws and regulations when using this tool.

> [!WARNING]
> **SSL verification is DISABLED** at the moment! This project is still under development. It will be added later. Use at your own risk.

---

This project is meant to download large quantities of data from an FTP server.

- You will be able to move finished downloads from the `finished` folder. The database keeps track of what has been downloaded already, even if the container is stopped and restarted, updated, or even removed and reinstalled as long as the database remains untouched.
- If your internet provider has a fair use policy (FUP), you can set certain hours in which it will download. In the other hours it will not download anything, avoiding going over the limit of your FUP.

If you encounter any problems or have suggestions, feel free to create an issue.

---

## Usage:

### 1. Configure environment

Copy the example environment config file:

```bash
cp .env.example .env
```

Edit the .env file with your settings.

```bash
nano .env
```

---

### 2. Start container

Navigate to the root of the project and start with:

```bash
docker-compose up -d
```

If your settings are correct, downloading should start immediatly if it is within the set hours.

---
### 3. Stop container

Navigate to the root of the project and stop the container with:

```bash
docker-compose down
```

---
