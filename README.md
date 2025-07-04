# mygd

Welcome to MyGD App! This is a cross-platform Flutter application to help users manage their gardens, identify plants, track tasks, and more.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Features
User authentication (login, signup, forgot password)
Plant, insect, soil, and tool identification and libraries
MyGarden: add plants, view history, manage tasks
Weather integration
User profile management
Getting Started
Prerequisites
Before you begin, make sure you have the following installed:
Flutter SDK
Dart SDK (usually included with Flutter)
Android Studio or Xcode (for mobile development)
A device or emulator to run the app

## Setup Steps
1. Clone the Repository

git clone https://github.com/daniellathu/mygd.git

2. Install Dependencies

flutter pub get

3. Configure Firebase

Place your google-services.json file in android/app/.

4. Run the App

flutter run

5. Build for Release

flutter build apk --split-per-abi

## Project Structure
lib/
  main.dart                # App entry point
  page/                    # UI pages (login, signup, home, etc.)
  src/
    main/
      model/               # Data models
      resources/           # Feature modules (plants, insects, soil, etc.)
      services/            # API and utility services
assets/
  images/                  # App images and logos
android/, ios/, web/, ...  # Platform-specific code
]
