# YadVault on TrueNAS SCALE

Needs TrueNAS SCALE 24.10 (Electric Eel) or later, where apps are Docker containers, with an apps
pool configured.

1. Open [docker-compose.yml](docker-compose.yml) and replace the two `CHANGE-ME` passwords (the
   database password in both places). Letters and digits only.
2. **Apps** → **Discover Apps** → **⋮** → **Install via YAML**. Name `yadvault`, paste the file,
   **Save**.
3. When both containers run, open the app → **Workloads** → the `app` container → **View Logs** and
   copy the setup code.
4. Open `http://<your TrueNAS>:8000`, enter the code and create your account.

The database and YadVault's files are Docker volumes in the apps pool. To keep YadVault's files in a
dataset instead, replace `data:/data` with a host path such as `/mnt/tank/apps/yadvault:/data` and
give that dataset to user and group 999 (the containers' user), or add `user: "568:568"` to the
`app` service and use a dataset owned by the `apps` user.

Update: the app's page → **Update** when TrueNAS offers it, or **Edit** → **Save** after the image
has a new release.
