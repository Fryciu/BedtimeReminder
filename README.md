## BedtimeReminder

**BedtimeReminder** is a desktop application built with Flutter designed to help users maintain a healthy sleep schedule. It functions by "locking" the screen (covering the desktop with a full-screen overlay) during scheduled hours, encouraging the user to stop using the computer and go to sleep.

## 🚀 Features

-   **Customizable Lock Schedules**: Create multiple alarm blocks with specific start and end times.
    
-   **Weekly Planning**: Select specific days of the week for each lock schedule.
    
-   **Full-Screen Overlay**: When a lock is active, the app expands to cover all connected displays and stays on top of all other windows.
    
-   **Custom Reminders**: Set personalized messages (e.g., "Time to sleep!", "Go to bed!") displayed during the lock period.
    
-   **System Tray Integration**: Runs quietly in the background; can be minimized to the system tray.
    
-   **Launch at Startup**: Automatically starts with the operating system to ensure schedules are never missed.
    
-   **Shutdown Integration**: Provides a quick "Turn off computer" button directly from the lock screen.
    
-   **Interactive Tutorial**: Includes a guided walkthrough for first-time users.
    

## 🛠 Tech Stack

-   **Framework**: [Flutter](https://flutter.dev/)
    
-   **Window Management**: `window_manager` & `screen_retriever` (for multi-monitor support).
    
-   **Persistence**: `shared_preferences` (JSON-based storage for alarms).
    
-   **System Integration**: `tray_manager` (system tray) and `launch_at_startup`.
    
-   **UI Components**: `tutorial_coach_mark` for onboarding.
    

## 📂 Project Structure

The core logic is contained within `main.dart`, structured as follows:

### 1\. Data Model (`AlarmBlock`)

Handles the properties of a schedule, including:

-   Time range (Start/End hours and minutes).
    
-   Active weekdays.
    
-   Custom lock message.
    
-   JSON serialization for local storage.
    

### 2\. Logic & State Management (`_TimeOutAppState`)

-   **`_checkLogic()`**: A periodic timer (running every 3 seconds) that evaluates if the current time falls within any active `AlarmBlock`.
    
-   **`_enableLock()`**: Triggered when a match is found. It calculates total screen real estate across all monitors and removes window decorations (frameless mode).
    
-   **`_disableLock()`**: Restores the window to its standard size and behavior.
    

### 3\. User Interface

-   **Main Dashboard**: A list view showing all configured schedules with toggle switches for activation.
    
-   **Edit Dialog**: A custom-built interface using `showTimePicker` and a multi-select day picker.
    
-   **Lock UI**: A minimalist black screen featuring the custom message and a system shutdown button.
    

## ⚙️ Configuration

The application includes a `isDebugMode` constant:

-   **`true`**: Enables a "DEBUG: Unlock" button on the lock screen and a "Stop process" option in the tray menu.
    
-   **`false`**: Standard user mode for maximum enforcement of sleep schedules.
    

## 📦 How to Build

1.  **Prerequisites**: Ensure Flutter is installed and configured for Desktop (Windows/macOS/Linux).
    
2.  **Install Dependencies**:
    
    ```
    flutter pub get
    ```
    
3.  **Run the App**:
    
    ```
    flutter run -d windows # or macos/linux
    ```
    

## 🎯 **Plans for the future**:
- Testing this app on Linux
    

* * *

## 📝 License
This software is released under the MIT License. You are free to:

- Copy and Distribute: You may copy and redistribute the material in any medium or format.

- Modify: You may remix, transform, and build upon the material for any purpose, even commercially.

- Sublicense: You are permitted to grant others the right to use the software under the same terms.

## 🛡️ Disclaimer of Warranty
The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

_Created as a utility for better digital well-being._
