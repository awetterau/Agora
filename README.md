# Agora

Agora is a mobile application designed for organizations to share events with the public, track attendance, and facilitate communication among members. Built with Flutter and Firebase, it offers a platform for event management, messaging, and organizational hierarchy.

![App Logo](https://github.com/awetterau/Agora/blob/main/agora/ios/Runner/Assets.xcassets/AppIcon.appiconset/120.png)

## Features

- **Event Management**: Create, view, and manage events for your organization.
- **Attendance Tracking**: Monitor member attendance at events.
- **Messaging System**: Integrated chat functionality for one-on-one and group conversations.
- **Role-based Permissions**: Manage organizational roles and permissions.
- **Member Profiles**: View and manage member information.
- **Dark Mode**: Sleek dark theme for comfortable viewing.

## Screenshots

<table>
  <tr>
    <td><img src="https://github.com/awetterau/Agora/blob/main/agora/ios/Runner/Assets.xcassets/Screenshots/WelcomeView.jpg" alt="Welcome Screen" /></td>
    <td><img src="https://github.com/awetterau/Agora/blob/main/agora/ios/Runner/Assets.xcassets/Screenshots/EventsView.jpg" alt="Events Screen" /></td>
    <td><img src="https://github.com/awetterau/Agora/blob/main/agora/ios/Runner/Assets.xcassets/Screenshots/CreateEventView.jpg" alt="New Event Screen" /></td>
    <td><img src="https://github.com/awetterau/Agora/blob/main/agora/ios/Runner/Assets.xcassets/Screenshots/AttendanceView.jpg" alt="Attendance Screen" /></td>
  </tr>
</table>

## Requirements

- Flutter 2.0+
- Dart 2.12+
- Firebase account

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/agora.git
   ```
2. Navigate to the project directory:
   ```
   cd agora
   ```
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Set up Firebase:
   - Create a new Firebase project
   - Add an Android and/or iOS app to your Firebase project
   - Download the Firebase configuration file (google-services.json for Android or GoogleService-Info.plist for iOS) and place it in the appropriate directory
5. Run the app:
   ```
   flutter run
   ```

## Configuration

Update the Firebase configuration in `lib/firebase_options.dart` with your own Firebase project details.

## Usage

1. Launch the app and sign in or create a new account.
2. Navigate through the bottom tabs to access different features:
   - Home: View upcoming events
   - Chat: Access messages and conversations
   - Organization: Manage organizational details
   - Profile: View and edit your profile

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
