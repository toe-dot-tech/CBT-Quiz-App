Since you have built a sophisticated Flutter CBT system with a custom Dart server and a Word-to-CSV transformer, your README needs to reflect that technical complexity.

Here is a comprehensive, professional `README.md` file tailored for your **CBT-Quiz-Software**.

---

# CBT Quiz Software 🚀

**A High-Performance Computer Based Testing (CBT) System for Local Networks.**

This software is designed to transform traditional Microsoft Word exam papers into dynamic, interactive digital exams. It features a robust Admin Dashboard for real-time monitoring and a lightweight Student Web UI.

## 🌟 Key Features

* **Word Transformer:** Automatically parse `.docx` files into structured quiz data.
* **Bulk Student Registry:** Upload student lists via CSV for instant authentication.
* **Real-time Admin Dashboard:** Monitor live progress, pass/fail rates, and connected clients.
* **Dynamic Server:** Built-in Dart `shelf` server that handles question serving and result storage.
* **Automated Reporting:** Generate official PDF result sheets at the click of a button.
* **Offline First:** Designed to run on a Local Area Network (LAN) without requiring internet.

---

## 🏗️ Technical Stack

* **Frontend:** Flutter (Desktop Admin & Web Student UI)
* **Backend:** Dart Shelf (Custom HTTP Server)
* **Data Storage:** CSV (Question Bank, Registry, and Results)
* **Networking:** IPv4 Local Hosting on Port 8080

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (3.x or higher)
* Dart SDK
* A Local Network (WiFi or Ethernet)

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/toe-dot-tech/CBT-Quiz-Software.git
cd CBT-Quiz-Software

```


2. **Install dependencies:**
```bash
flutter pub get

```


3. **Run the Admin Dashboard:**
```bash
flutter run -d linux # or windows

```



---

## 🛠️ How to Prepare an Exam

### 1. Questions (Word Transformer)

Format your Word document as follows:

* Use `1.`, `2.` for questions.
* Use `A.`, `B.`, `C.`, `D.` for options.
* Include `ANS: A` at the end of each question.
* Use the **Word Transformer** button in the Admin UI to upload.

### 2. Students (Bulk Registry)

Prepare a CSV file named `registered_students.csv` with these columns:
`MATRIC, SURNAME, FIRSTNAME`
Upload it via the **Bulk Student Upload** button.

### 3. Start the Server

Click **START EXAM** in the sidebar. The IP address (e.g., `http://192.168.1.5:8080`) will be displayed. Students can access the quiz by entering this URL in their browser.

---

## 📊 Monitoring & Reports

The Admin Dashboard provides:

* **Live Activity Log:** See exactly who is logged in and their current progress.
* **Performance Chart:** A pie chart showing Pass/Fail distribution.
* **PDF Exports:** Professional grade reports for academic filing.

---

## 📁 Project Structure

```text
lib/
├── main.dart             # App entry point
├── server/
│   └── quiz_server.dart  # Dart Shelf server logic
├── services/
│   └── result_storage.dart # CSV & PDF handling
└── views/
    └── admin_view.dart   # Admin Dashboard UI
assets/
└── web/                  # Compiled Student Web UI

```

---

## 🛡️ Security

* **Force-Sync:** The server requires a valid Matric number and Surname to grant access.
* **Local Storage:** Results are saved directly to `quiz_results.csv` on the host machine to prevent data loss.

---

## 🤝 Contribution

Developed by **Toe Tech**. Feel free to fork this repo and submit pull requests.

---

### Pro-Tip for your GitHub:

I recommend creating a file named `README.md` in your project's root folder and pasting the content above into it.

**Would you like me to help you create a "License" file (like MIT) to go along with this README?**