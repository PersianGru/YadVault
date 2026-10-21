# YadVault on Synology DSM

Needs DSM 7.2 or later with **Container Manager** (Package Center), a model that runs Docker
(x86-64 or ARMv8), and 2 GB of memory or more.

1. Open [docker-compose.yml](docker-compose.yml) and replace the two `CHANGE-ME` passwords (the
   database password in both places). Letters and digits only.
2. Container Manager → **Project** → **Create**. Project name `yadvault`, any path (for example
   `/docker/yadvault`), source **Upload docker-compose.yml**, choose the file. Leave Web Station off.
3. **Next** until **Done**. Container Manager pulls the images and starts both containers.
4. Container Manager → **Container** → `yadvault` → **Log**: copy the setup code.
5. Open `http://<your NAS>:8000`, enter the code and create your account.

The database and YadVault's files are kept in Docker volumes (`yadvault_db`, `yadvault_data`), which
Container Manager keeps with the project. To use another port, change `"8000:8000"` to
`"8443:8000"`, for example. For access from outside your home network, use DSM's reverse proxy
(Control Panel → Login Portal → Advanced) with HTTPS rather than opening the port.

Update: Container Manager → Project → `yadvault` → **Action** → **Build** pulls the new image.
