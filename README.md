# Sahayak: AI Educational Assistant

An offline-first, AI-powered educational assistant built with Flutter for rural Indian teachers.

Sahayak aims to empower educators in resource-constrained environments by providing intelligent tools for lesson planning, content creation, and classroom management, all accessible with or without an internet connection.

## Table of Contents

- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [AI Integration](#ai-integration)
- [Voice Support](#voice-support)
- [Firestore Data Model](#firestore-data-model)
- [Security](#security)
- [Author](#author)

## Features

- **Teacher Authentication**: Secure login using Email/PIN or Phone Number (OTP), with persistent sessions.
- **Personalized Dashboard**: A central hub displaying teacher profile, grade-subject combinations, and quick access to all features.
- **Agentic AI System**: Core functionalities are driven by autonomous agents built on a Perceive-Plan-Act-Learn pattern.
  - **Whisper Mode Agent**: Proactively delivers bite-sized audio micro-lessons.
  - **Ask Me Later Agent**: An AI-powered Q&A queue that answers teacher queries with context.
  - **Visual Aid Generator Agent**: Creates diagrams, charts, and visual content from text or voice prompts.
- **Hyperlocal Content Generation**: Generates culturally relevant stories and examples in various Indian languages using Vertex AI, tailored to specific topics and grade levels.
- **Offline-First Capability**: The entire application is designed to work seamlessly offline. All data is cached locally using Hive and synced with Firestore when a connection is available.
- **Student Data Management**: Comprehensive module to manage student profiles, track daily attendance, and record academic scores.
- **Automated Weekly Planner**: Allows teachers to upload a curriculum, set a session timeline, and automatically generate a distributable weekly teaching plan. The planner dynamically reschedules incomplete topics.
- **Voice-Enabled Interaction**: Hands-free control using Speech-to-Text and audio feedback via Text-to-Speech for key features.

## Architecture Overview

Sahayak is built on a robust, layered architecture designed for scalability, maintainability, and offline resilience.

1.  **UI Layer (Flutter)**: The user-facing layer, built with Material 3. It includes all pages, widgets, and user interaction logic.
2.  **Service Layer**: This layer contains the core business logic, abstracting functionalities into dedicated services (e.g., `AuthService`, `PlannerService`, `VertexAIService`). It acts as the bridge between the UI and the underlying data and agent layers.
3.  **Agent Layer**: The intelligent core of the app. It uses an agentic AI pattern where different agents (`WhisperModeAgent`, `AskMeLaterAgent`, etc.) handle specific tasks. These agents perceive the user's context, plan actions, execute them using the service layer, and learn from interactions.
4.  **Data Layer**: Manages all data persistence.
    -   **Hive**: A lightweight and fast key-value database used for local caching of all application data, enabling the offline-first experience.
    -   **Cloud Firestore**: The cloud NoSQL database used as the single source of truth. Data is synced between Hive and Firestore.
    -   **Firebase Storage**: Used for storing file uploads like curriculum PDFs.

### Offline-First Strategy

Every data write operation first commits to the local Hive cache, ensuring instant UI updates and functionality without an internet connection. A sync queue manages changes, which are then pushed to Firestore in the background once connectivity is restored.

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **Backend & Cloud**:
  - **Firebase**: Firestore, Firebase Authentication, Firebase Storage
  - **Google Cloud Platform**: Vertex AI
- **AI & ML**:
  - **Vertex AI (Gemini 1.5 Pro)**: For all generative AI tasks (content generation, Q&A).
  - **Google Cloud Speech-to-Text & Text-to-Speech**: Implemented via `speech_to_text` and `flutter_tts` packages.
- **Local Storage**: Hive
- **Key Packages**:
  - `firebase_core`, `cloud_firestore`, `firebase_auth`
  - `hive`, `hive_flutter`, `path_provider`
  - `googleapis`, `googleapis_auth`
  - `file_picker`, `image_picker`
  - `intl`

## Project Structure

The `/lib` directory is organized to separate concerns, making the codebase clean and scalable.

<pre>
lib/  
├── agents/             # Core AI agents and their memory systems  
├── features/           # UI and state logic for each distinct app feature  
├── models/             # Data models for Firestore and local objects  
├── services/           # Business logic and third-party API integrations  
├── widgets/            # Reusable UI widgets shared across features  
├── config/             # Configuration for APIs and environment settings  
└── main.dart           # Main application entry point and routing
</pre>

## Installation

1.  **Prerequisites**:
    -   Flutter SDK (v3.x.x or higher)
    -   An editor like VS Code or Android Studio.
    -   A configured Firebase project.

2.  **Clone the Repository**:
    sh
    git clone https://github.com/your-repo/sahayak.git
    cd sahayak
    

3.  **Firebase Setup**:
    -   Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files in the respective platform directories.
    -   Set up Authentication (Email, Phone) and Firestore in your Firebase console.

4.  **Install Dependencies**:
    sh
    flutter pub get
    

5.  **Run the App**:
    sh
    flutter run
    

## How It Works

The application flow is designed to be intuitive and resilient.

1.  **Authentication**: The user logs in. Credentials are validated by `AuthService` against Firebase Auth. The user's profile is fetched from Firestore or the local Hive cache.
2.  **Dashboard**: The main dashboard loads, presenting quick actions and a summary of the teacher's classes. All data is rendered from the local cache first for a fast startup.
3.  **Feature Interaction**: The user selects a feature, like the "Weekly Planner".
4.  **Offline Operation**: The user creates a new curriculum plan. The `PlannerService` saves the plan directly to the Hive cache. The UI updates instantly.
5.  **Online Sync**: A background process detects an internet connection and syncs the new plan from the Hive cache to Firestore. Any data from the cloud is simultaneously pulled down to keep the local cache fresh.
6.  **AI Feature Usage**: The user requests a "Hyperlocal Story".
    -   The `HyperlocalContentService` calls the `VertexAIService`.
    -   A carefully constructed prompt is sent to the Gemini Pro model.
    -   The generated story is returned, displayed to the user, and cached in Hive and Firestore.
    -   If offline, a pre-defined template story is provided from the local cache as a fallback.

## AI Integration

AI is central to Sahayak's intelligence. The `VertexAIService` provides a unified interface to Google's Gemini Pro model.

**Prompt Engineering**: To ensure relevant and high-quality responses, prompts are dynamically constructed by combining multiple layers of context:
-   **System Context**: A base prompt defining the AI's persona ("You are Sahayak, an AI assistant for rural Indian teachers...").
-   **Task Context**: Specific instructions for the task (e.g., "Create a simple story...", "Explain this concept...").
-   **Cultural & Educational Context**: Details about the rural Indian environment, multi-grade classrooms, and simple language requirements.
-   **User-Provided Data**: The specific topic, grade, and language requested by the teacher.

This multi-layered approach ensures the AI's output is not just accurate but also practical and culturally appropriate for the target user.

## Voice Support

Sahayak provides hands-free capabilities through its `VoiceService`.
-   **Speech-to-Text (STT)**: The `speech_to_text` package captures user voice commands, which are then processed by the agents.
-   **Text-to-Speech (TTS)**: The `flutter_tts` package converts text responses from the AI into natural-sounding speech, enabling features like audio lessons and story narration.

## Firestore Data Model

The Firestore database is structured to be scalable and secure, with data partitioned by teacher.

<pre>
/teachers/{teacherId}/
  ├── profile: {name, grades, subjects}
  ├── students/{studentId}: {studentInfo, attendance, scores}
  ├── curriculums/{curriculumId}: {metadata, topicsList}
  ├── weekly_plans/{planId}: {week, topicsWithStatus}
  ├── hyperlocal_stories/{storyId}: {storyData}
  └── visual_aids/{aidId}: {visualAidData}
</pre>

## Security

-   **Authentication**: User access is protected by Firebase Authentication, ensuring only verified users can enter the app.
-   **Data Isolation**: Firestore Security Rules are configured to ensure that a teacher can only read and write their own data, using the `{teacherId}` as a primary security key.
-   **API Key Protection**: Service account credentials for Google Cloud are handled securely and are not exposed on the client side.

---
