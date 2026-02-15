# CBT Quiz App - Flutter

A Computer-Based Testing (CBT) Quiz Application built with Flutter. This is a client-server architecture where one main device runs as a server (providing `.exe` for Windows) and other devices on the same LAN/WiFi network connect as clients to take quizzes.

## 📋 Project Overview

### Architecture
```
┌─────────────────────────────────────────────┐
│         SERVER (Main Device)                 │
│  ┌──────────────────────────────────────┐   │
│  │  Flutter App with Dart Server        │   │
│  ├──────────────────────────────────────┤   │
│  │  - HTTP Server (port 8080)           │   │
│  │  - SQLite Database                   │   │
│  │  - Quiz Management                   │   │
│  │  - Student Management                │   │
│  │  - Results & Analytics               │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
           ↕ (HTTP Communication)
┌──────────────────────────────────────────────┐
│    CLIENTS (Student Devices on LAN)          │
│  ┌────────────────┐  ┌────────────────┐     │
│  │ Flutter Client │  │ Flutter Client │ ... │
│  ├────────────────┤  ├────────────────┤     │
│  │ Login Screen   │  │ Login Screen   │     │
│  │ Quiz Interface │  │ Quiz Interface │     │
│  │ Results View   │  │ Results View   │     │
│  └────────────────┘  └────────────────┘     │
└──────────────────────────────────────────────┘
```

### Technology Stack
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod (Provider pattern)
- **Navigation:** GoRouter (type-safe routing)
- **Database:** SQLite (local storage)
- **Networking:** HTTP + Socket.io (real-time communication)
- **Server:** Shelf Framework (Dart-based HTTP server)

## 🎯 Core Features

### Server Features
1. **Quiz Management** - Create, edit, delete quizzes and manage questions
2. **Student Management** - Register and enroll students
3. **Testing & Monitoring** - Monitor live student progress in real-time
4. **Results & Analytics** - View scores, export results, analyze performance

### Client Features
1. **Authentication** - Login with matriculation number and surname
2. **Quiz Interface** - Clean interface with timer and navigation
3. **Offline Resilience** - Cache answers locally and sync when reconnected
4. **User Experience** - Results display and score breakdown

## 📁 Project Structure
The project follows a modular architecture with clear separation of concerns including lib/main.dart, config/, models/, services/, providers/, screens/, widgets/, utils/, and assets/

## 🚀 Getting Started
Prerequisites: Flutter SDK v3.0+, Dart SDK, Git
Installation: Clone repo, run flutter pub get, then flutter run

## 📞 Support
For issues or questions, please open an issue on GitHub.