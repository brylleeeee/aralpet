# AralPet – Team Setup Guide

This guide takes you from a fresh Windows laptop to running AralPet and pushing your own changes. Follow the parts in order. Each part ends with a check, so you know it worked before moving on.

Repository: https://github.com/brylleeeee/aralpet

## What is in this repo

```
aralpet/
├── mobile/   Flutter app (Dart): Riverpod, Dio, go_router, flutter_secure_storage, fl_chart
├── api/      Laravel 13 RESTful API (PHP 8.3+): Sanctum tokens, MySQL/MariaDB
└── README.md
```

The phone app talks to the API at `http://127.0.0.1:8000/api/v1`. During development the API runs on your own laptop, and your phone reaches it through a USB cable (`adb reverse`).

---

## Part 1 – Install the requirements

You only do this part once per laptop.

### 1.1 Git

1. Download from https://git-scm.com and install with the default options.
2. Open **Git Bash** and set your name and email (use the email of your GitHub account):
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```

### 1.2 VS Code

Install VS Code from https://code.visualstudio.com, then install these extensions:

- Flutter (installs Dart too)
- PHP Intelephense
- Laravel (optional)

In VS Code, set the terminal to Git Bash: press `Ctrl+Shift+P`, run **Terminal: Select Default Profile**, choose **Git Bash**. All commands in this guide are written for Git Bash.

### 1.3 XAMPP (MySQL database)

1. Download from https://www.apachefriends.org and install.
2. Open the **XAMPP Control Panel** and click **Start** next to **MySQL**. You do not need Apache for this project.

XAMPP uses MariaDB instead of MySQL 8. That is fine for this project.

### 1.4 PHP 8.3 or newer

The API uses Laravel 13, which needs **PHP 8.3+**. Check which PHP XAMPP has:

1. Add `C:\xampp\php` to your Windows **Path** (see "How to edit Path" below), then reopen VS Code.
2. Run:
   ```bash
   php -v
   ```

If it says **8.3 or higher**, skip to 1.5.

If it says **8.2** (common with XAMPP), install a newer PHP separately and use it instead:

1. Download PHP 8.3 or 8.4, **VS16/VS17 x64 Thread Safe** zip, from https://windows.php.net/download.
2. Extract it to `C:\php`.
3. In `C:\php`, copy `php.ini-development` and rename the copy to `php.ini`.
4. Open `php.ini` and remove the `;` at the start of these lines:
   ```
   extension_dir = "ext"
   extension=curl
   extension=fileinfo
   extension=mbstring
   extension=openssl
   extension=pdo_mysql
   extension=zip
   ```
5. In your Windows Path, replace `C:\xampp\php` with `C:\php`. Reopen VS Code and check `php -v` again.

Keep using XAMPP for MySQL only.

### 1.5 Composer

1. Download **Composer-Setup.exe** from https://getcomposer.org and run it.
2. When it asks for PHP, choose the PHP you are using (`C:\php\php.exe` or `C:\xampp\php\php.exe`).
3. Reopen VS Code and check:
   ```bash
   composer -V
   ```

### 1.6 Android Studio (Android SDK)

You need Android Studio for the Android SDK, even though you will write code in VS Code.

1. Download from https://developer.android.com/studio and install. Finish the setup wizard on first launch.
2. Open **More Actions → SDK Manager** (or **Tools → SDK Manager** if a project is open).
3. Go to the **SDK Tools** tab, tick **Show Package Details** at the bottom right, and make sure these are ticked:
   - Android SDK Build-Tools (latest)
   - Android SDK Command-line Tools (latest)
   - Android SDK Platform-Tools
   - CMake
   - **NDK (Side by side) → 28.2.13676358** (this exact version; the build fails without it)
4. Click **Apply → OK** and wait for the downloads to finish. The NDK is 1–2 GB.

### 1.7 Flutter SDK

1. Download the latest **stable** Flutter for Windows from https://docs.flutter.dev/get-started/install/windows and extract it to `C:\dev\flutter`.
   Do not put it in `C:\Program Files`, OneDrive, or a path with spaces.
2. Add `C:\dev\flutter\bin` to your Windows Path.
3. Reopen VS Code and run:
   ```bash
   flutter --version
   ```
   This project needs a Flutter version that comes with **Dart 3.13 or newer**. If your version is older, run `flutter upgrade`.

### 1.8 Add adb to Path

`adb` connects your laptop to your phone. Add this folder to your Windows Path (replace `YOUR-USER` with your Windows username):

```
C:\Users\YOUR-USER\AppData\Local\Android\Sdk\platform-tools
```

### 1.9 Turn on Windows Developer Mode

Flutter plugins need symlink support on Windows.

Open **Settings → Update & Security → For developers** (Windows 11: **Settings → System → For developers**) and switch **Developer Mode** on.

### 1.10 Final check

Reopen VS Code, then run:

```bash
flutter doctor --android-licenses
flutter doctor
php -v
composer -V
adb version
```

Type `y` for each license. In `flutter doctor`, the **Flutter** and **Android toolchain** lines must show a check mark. You can ignore Visual Studio, Chrome and Xcode; this project only targets Android.

### How to edit Path

1. Press the Windows key, search **Edit the system environment variables**, and open it.
2. Click **Environment Variables...**
3. Under **User variables**, select **Path → Edit → New**, paste the folder, and click **OK** on every window.
4. **Close and reopen VS Code** so the terminal sees the change.

### Optional: Postman

Install Postman from https://www.postman.com/downloads to test API endpoints without the app.

---

## Part 2 – Get access and clone the repo

1. Ask the repo owner to add you as a **collaborator**. Accept the invitation from your email or from https://github.com/notifications.
2. Clone the repo:
   ```bash
   mkdir -p /c/projects
   cd /c/projects
   git clone https://github.com/brylleeeee/aralpet.git
   ```
   The first time you push, a browser window opens to sign in to GitHub.

Check: `C:\projects\aralpet` contains the `mobile` and `api` folders.

---

## Part 3 – Set up the API (`api/`)

Open VS Code with **File → Open Folder → `C:\projects\aralpet\api`**. Use this window for all backend work.

1. Install the PHP packages and create your environment file:
   ```bash
   composer install
   cp .env.example .env
   php artisan key:generate
   ```
2. Open `.env` and fill in the admin account at the top (choose your own values):
   ```
   ADMIN_EMAIL=admin@aralpet.test
   ADMIN_PASSWORD=Admin12345
   ```
   The database lines are already correct for XAMPP (`DB_DATABASE=aralpet`, `DB_USERNAME=root`, empty password).
3. Make sure MySQL is running in XAMPP. Open http://localhost/phpmyadmin, click **New**, name the database `aralpet`, and click **Create**.
4. Create the tables and the starting data:
   ```bash
   php artisan migrate --seed
   ```
5. Start the API:
   ```bash
   php artisan serve
   ```
   Leave this terminal open. The API only runs while it is open.

Check:

- http://127.0.0.1:8000/up in your browser shows a green "Application up" page.
- The terminal says `Server running on [http://127.0.0.1:8000]`. If it says port **8001**, another server is still running; stop it (`Ctrl+C` in that terminal) and start again.

Opening `http://127.0.0.1:8000/api/v1/me` in a browser shows an error "Route [login] not defined". That is expected, because browsers do not ask for JSON. Test API routes in Postman with the header `Accept: application/json` instead.

Your `.env` file and the `vendor` folder are never uploaded to GitHub. Every member creates their own.

---

## Part 4 – Set up the mobile app (`mobile/`)

Open a **second** VS Code window with **File → Open Folder → `C:\projects\aralpet\mobile`**. Use this window for all Flutter work.

1. Download the Dart packages:
   ```bash
   flutter pub get
   ```
   The blue "newer version available" lines are normal. Do not upgrade packages unless the team agrees.

2. Prepare your Android phone (Android 7 or newer):
   - **Settings → About phone** (sometimes **Software information**) → tap **Build number** 7 times.
   - **Settings → Developer options** → turn on **USB debugging**.
   - Xiaomi/Redmi/POCO: also turn on **Install via USB** and **USB debugging (Security settings)**.
   - Oppo/Realme/Vivo: also turn on **Disable permission monitoring** if you see it.

3. Plug the phone in with a cable that transfers data. On the phone, tap **Allow** on "Allow USB debugging?" and tick **Always allow from this computer**.

4. Check that the laptop sees the phone:
   ```bash
   adb devices
   ```
   Your phone should be listed with the word `device`. If it says `unauthorized`, unplug, replug and accept the prompt.

5. Connect the phone to the API running on your laptop:
   ```bash
   adb reverse tcp:8000 tcp:8000
   ```

6. Run the app:
   ```bash
   flutter run
   ```
   The **first build takes 5–15 minutes**. Later builds are much faster. If your phone asks to allow the install, tap **Install anyway**.

Check: the AralPet login screen opens on your phone. Tap **Register**, create an account, and you land on the Home screen. In phpMyAdmin, the `users`, `progress` and `pets` tables each have a new row, and the `php artisan serve` terminal shows a `/api/v1/auth/register` line.

While the app runs, use these keys in the terminal:

| Key | Action |
| --- | --- |
| `r` | Hot reload (shows code changes instantly) |
| `R` | Hot restart (restarts the app) |
| `q` | Quit |

### Using an emulator instead of a phone

An emulator needs about 16 GB of laptop RAM to run comfortably, so a real phone is recommended. If you use one anyway, create it in Android Studio's **Device Manager** with an **API 33 or 34, x86_64, Google APIs** image and **2 GB RAM**. `adb reverse tcp:8000 tcp:8000` works for emulators too, so no code change is needed.

---

## Part 5 – Daily routine

Every time you sit down to work:

1. Start **MySQL** in XAMPP.
2. **api** window:
   ```bash
   git pull
   composer install
   php artisan migrate
   php artisan serve
   ```
3. Plug in your phone, then in the **mobile** window:
   ```bash
   flutter pub get
   adb reverse tcp:8000 tcp:8000
   flutter run
   ```

`composer install`, `php artisan migrate` and `flutter pub get` are quick when nothing changed. Run them after every `git pull`, because a teammate may have added packages or tables.

Run `adb reverse tcp:8000 tcp:8000` again every time you replug the phone or restart the laptop.

---

## Part 6 – How to push your work (Git workflow)

Both projects are in one repo, so Git commands work from either the `mobile` or the `api` window.

### Work on a branch, not directly on main

```bash
git checkout main
git pull
git checkout -b feature/tasks-screen
```

Name branches after what you are doing, for example `feature/focus-timer`, `feature/progress-endpoint` or `fix/login-error`.

### Save and upload your changes

```bash
git add .
git commit -m "Add tasks list screen with mock data"
git push -u origin feature/tasks-screen
```

Write commit messages that say what changed. Commit small, working steps rather than one huge commit at the end.

### Merge into main with a Pull Request

1. On GitHub, click **Compare & pull request** for your branch.
2. Describe what you changed and how to test it, then create the pull request.
3. Ask a teammate to look at it, then click **Merge pull request**.
4. Back in VS Code:
   ```bash
   git checkout main
   git pull
   ```

### If you get a merge conflict

Git marks conflicting parts in the file with `<<<<<<<`, `=======` and `>>>>>>>`. VS Code shows buttons above them: **Accept Current**, **Accept Incoming** or **Accept Both**. Pick the right version, save, then run `git add .` and `git commit`. If you are unsure, ask the person who wrote the other change before deciding.

### Never commit these

`.env`, `vendor/`, `build/`, `.dart_tool/` and `node_modules/`. They are already in `.gitignore`, so a normal `git add .` skips them. Never paste passwords or tokens into code.

---

## Part 7 – How the code is organized

### Mobile (`mobile/lib/`)

```
main.dart          App entry point
core/              api_service (Dio + token), env (API URL), router, theme, token_storage
models/            Dart classes made from JSON (user, progress, ...)
repositories/      Call the API and turn JSON into models
providers/         Riverpod state for each screen
screens/           One folder per feature: auth, dashboard, tasks, focus, pet, ...
widgets/           Reusable pieces: xp_bar, pet_view, streak_chip, ...
```

Data flows one way: **screen → provider → repository → api_service → Laravel API**. A screen never calls the API directly.

To add a feature, for example tasks:

1. `models/task.dart` with a `fromJson` that matches the API's JSON keys
2. `repositories/task_repository.dart` that calls `/tasks` through `ApiService`
3. `providers/task_provider.dart`
4. The screen in `screens/tasks/`

Things to know:

- Login state lives in `providers/auth_provider.dart`. The router in `core/router.dart` automatically sends logged-out users to Login and logged-in users to Home, so screens do not navigate after login or logout.
- `ApiService` turns API errors into an `ApiException` with a readable `message`, so a screen can show `e.message` directly.
- The API URL is in `core/env.dart`.
- The dashboard still uses mock data (`repositories/progress_repository.dart`) until the API has a progress endpoint.

### API (`api/`)

```
routes/api.php                     All routes, under the /api/v1 prefix
app/Http/Controllers/Api/V1/       Controllers (Auth, Subject, Task, ...)
app/Http/Requests/                 Validation rules (Form Requests)
app/Http/Resources/                Shape of the JSON sent back
app/Http/Middleware/               EnsureRole (student/admin), EnsureActive
app/Policies/                      Ownership checks (a student can only touch their own data)
app/Models/                        Eloquent models
database/migrations/, seeders/     Tables and starting data
```

API conventions:

- JSON keys use `snake_case` (`due_date`, `total_xp`).
- Single records are wrapped in `"data"`. Lists from paginated endpoints have `data`, `links` and `meta`.
- Validation errors return **422** with an `errors` object. Unauthenticated requests return **401**. Wrong role returns **403**. Too many login attempts return **429**.
- Login and register return `{ "data": { "token": "...", "user": { ... } } }`.
- After you change routes, run `php artisan route:list --path=api` to see every endpoint.

### Current progress

| Feature | API | Mobile app |
| --- | --- | --- |
| Register, login, logout, GET /me | Done | Done (connected) |
| Subjects CRUD | Done (not yet tested) | Not started |
| Tasks CRUD | Done (not yet tested) | Placeholder screen |
| Mark task complete (+XP) | Not started | Not started |
| Progress (XP, level, streak) | Not started | Dashboard with mock data |
| Focus sessions | Not started | Placeholder screen |
| Pet, badges, weekly summary | Not started | Placeholder screens |
| Admin | Not started | Not started |

Update this table when you finish a feature.

---

## Part 8 – Troubleshooting

| Problem | Fix |
| --- | --- |
| `adb: command not found` | Add `...\Android\Sdk\platform-tools` to Path (Part 1.8) and reopen VS Code. |
| App says "Cannot reach the server" | Check `php artisan serve` is running on port **8000**, then run `adb reverse tcp:8000 tcp:8000` again. |
| `flutter devices` does not list the phone | Use a data cable, try another USB port, accept the "Allow USB debugging?" prompt, or tap **Revoke USB debugging authorizations** in Developer options and reconnect. |
| Build fails with "NDK 28.2.13676358" | Install that exact NDK version in Android Studio's SDK Manager (Part 1.6). |
| "Building with plugins requires symlink support" | Turn on Windows Developer Mode (Part 1.9), then run `flutter pub get` again. |
| `composer install` complains about the PHP version | You are on PHP 8.2. Install PHP 8.3+ (Part 1.4). |
| `composer install` says an extension is missing | Remove the `;` before that `extension=` line in `php.ini`. |
| `php artisan migrate` says connection refused | MySQL is not started in XAMPP, or the `aralpet` database does not exist yet. |
| Browser shows "Route [login] not defined" | Normal for browsers. Test with Postman and the `Accept: application/json` header. |
| Red errors in VS Code after `git pull` | Run `flutter pub get` (mobile) or `composer install` (api), then `Ctrl+Shift+P` → **Dart: Restart Analysis Server**. |
| `git push` says "Repository not found" | Accept the collaborator invitation, or sign in to the right GitHub account (remove old `git:https://github.com` entries in Windows Credential Manager). |
| The first `flutter run` seems stuck at "Running Gradle task" | It is downloading build tools. Wait up to 15 minutes; only stop if it prints **FAILURE**. |

If you are stuck, send the group chat a screenshot that shows the full error message and the command you ran.
