# YadVault on Unraid

Two Docker templates: the database (**YadVault-DB**) and **YadVault**. They find each other on a
custom Docker network named `yadvault`.

1. Once, in the Unraid terminal: `docker network create yadvault`. Then Settings → Docker → (stop
   Docker) → **Preserve user defined networks: Yes** → start Docker, so the network survives reboots.
2. Copy both XML files to the flash drive, `/boot/config/plugins/dockerMan/templates-user/`
   (as `my-YadVault-DB.xml` and `my-YadVault.xml`).
3. Docker → **Add Container** → template **YadVault-DB**. Set the database password (letters and
   digits) → **Apply**.
4. Docker → **Add Container** → template **YadVault**. Put the same password into **Database
   address** in place of `CHANGE-ME`, and choose another password for the
   **Read-only address** → **Apply**.
5. YadVault's log (the container icon → **Logs**) shows the setup code. Open the web UI from the
   container's menu, enter the code and create your account.

Files: `/mnt/user/appdata/yadvault/db` (the database) and `/mnt/user/appdata/yadvault/data`
(uploads, copied media, backups). YadVault runs as `nobody:users` (99:100), the owner of appdata
folders on Unraid. Back up with Settings → Backups, or with the appdata backup plugin while both
containers are stopped.

When the templates are in Community Applications, step 2 becomes a search in the Apps tab.
