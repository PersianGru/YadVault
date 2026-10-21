# YadVault on umbrelOS

[yadvault/](yadvault) is an app folder for an umbrelOS **community app store**: the app manifest
(`umbrel-app.yml`) and its `docker-compose.yml`. umbrelOS starts its own proxy in front of the app
(`app_proxy`) and gives the app stable passwords (`APP_PASSWORD`, `APP_SEED`), so there is nothing to
fill in.

To offer it: put the `yadvault` folder in a community app store repository (a Git repository with
an `umbrel-app-store.yml` at its root, whose `id` becomes the prefix of the app id), then in
umbrelOS: App Store → ⋯ → **Community App Stores** → add the repository's address → install
YadVault. After the first start, right-click YadVault → **Troubleshoot** shows the log with the
setup code; open YadVault, enter it and create your account.

The files are kept in the app's data folder (`data/db` and `data/app`).
