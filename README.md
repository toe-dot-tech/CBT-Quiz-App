# CBT Quiz App

## Project Documentation

### Architecture
The CBT Quiz App is built using a client-server architecture where the client-side is developed using React, and the server-side is powered by Node.js and Express. The application interacts with a MongoDB database for data storage and retrieval.

### Features
- **User Authentication:** Secure login and registration for users.
- **Quiz Management:** Create, update, and delete quiz questions and options.
- **Real-time Scoring:** Instant scoring after quiz submission to provide feedback.
- **Responsive Design:** Works seamlessly on various screen sizes.
- **Analytics:** Insights into user performance and quiz statistics.

### Setup Instructions
1. **Clone the Repository**  
   `git clone https://github.com/toe-dot-tech/CBT-Quiz-App.git`

2. **Navigate to Project Directory**  
   `cd CBT-Quiz-App`

3. **Install Dependencies**  
   For the client:  
   `cd client && npm install`  
   For the server:  
   `cd server && npm install`

4. **Set Up Environment Variables**  
   Create a `.env` file in both `client` and `server` directories and add the required environment variables as per the `.env.example` files.

5. **Run the Application**  
   Start the server:  
   `cd server && npm start`  
   Start the client:  
   `cd client && npm start`

### Usage Guide
- Navigate to `http://localhost:3000` in your browser to access the application.
- Log in with your credentials to access user-specific features.
- Use the dashboard to manage quiz content and view analytics.
- Participate in quizzes and check scores immediately after submissions.