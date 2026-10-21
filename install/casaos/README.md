# YadVault on CasaOS

1. Open [docker-compose.yml](docker-compose.yml) and replace the two `CHANGE-ME` passwords (the
   database password in both places). Letters and digits only.
2. CasaOS → **App Store** → **Custom Install** → the import button (⇪) at the top right → paste
   the file → **Submit** → **Install**.
3. When YadVault shows as running, read the setup code in its log: the Logs view of the app (in
   newer CasaOS versions), or in a terminal `docker logs yadvault`.
4. Open YadVault from the dashboard (port 8000), enter the code and create your account.

The database and YadVault's files are Docker volumes (`yadvault_db`, `yadvault_data`).
