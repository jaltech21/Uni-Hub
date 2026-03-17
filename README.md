### Project Title

**UniHub: The All-in-One Student Virtual Assistant**

---

### Project Description

**UniHub** is a web-based virtual assistant built with **Ruby on Rails** designed to streamline and centralize academic life for students and teachers. Our primary goal is to provide a unified platform that replaces scattered tools and manual processes, making organization and communication effortless.

For **students**, UniHub acts as a personal academic hub. They can **create and manage schedules**, receive automated **reminders for classes and deadlines**, and **submit assignments digitally**. The platform also features a robust suite of study tools, including a dedicated **note-taking module** with a **text summarization tool** to help them digest information more efficiently. Looking ahead, UniHub will offer **AI-powered assistance for exam preparation**, providing students with possible exam questions and study support.

For **teachers**, UniHub simplifies administrative tasks. They can easily **upload and manage assignments** and create **digital attendance lists** for students to fill in. This single point of entry for all academic tasks fosters better collaboration and reduces the administrative burden on both students and educators.
---

### **Core Functionalities**

UniHub will be built on the principle of providing essential, reliable tools for academic management. The core functionalities are organized around three key user experiences: **User & Account Management**, **Academic Management**, and **Study & Collaboration**.

#### **1. User & Account Management**

* **Secure Authentication**: A robust login and registration system for both students and teachers to ensure data privacy and security. The system will support a single sign-on experience for different user roles.
* **User Profiles**: Students and teachers will have customizable profiles, allowing them to manage their information, set preferences, and view their academic history.

#### **2. Academic Management**

* **Assignment Submission**:
    * **Teachers**: Can create, edit, and delete assignments, specifying due dates, descriptions, and file requirements. They can also view a dashboard of submitted assignments and download student files.
    * **Students**: Can view a chronological list of their assignments and submit completed work in various formats (e.g., PDF, DOCX, ZIP). They will receive confirmation upon successful submission.
* **Scheduling and Reminders**:
    * **Students**: Can create and edit their personal academic schedules, including classes, study sessions, and exams. They will receive automated, customizable reminders via email or in-app notifications to ensure they are always on track.
* **Attendance Tracking**:
    * **Teachers**: Can generate digital attendance lists for each class.
    * **Students**: Can digitally mark their attendance on the teacher-generated lists. This feature provides a quick and accurate way to track class presence without physical paperwork.

#### **3. Study & Collaboration**

* **Integrated Note-Taking**: A rich-text editor that allows students to create, save, and organize their notes by subject.
* **Note Summarization**: A tool that uses natural language processing to condense lengthy text into concise summaries, helping students quickly grasp key concepts from readings or their own notes.
* **Exam Preparation**: An interactive feature that helps students with possible exam questions. The system will analyze a student's notes and course content to generate relevant practice questions and provide hints, helping them prepare for tests.

---

### **User Stories**

Here are the user stories that will guide the development process for UniHub, ensuring each feature is implemented with the end-user's needs in mind.

#### **As a Student**

* **Schedule and Reminders**
    * As a student, I want to be able to **create my weekly class schedule** so I can see all my classes in one place.
    * As a student, I want to receive **notifications or email reminders** for my classes 15 minutes before they start so I don't forget to attend.
    * As a student, I want to be able to **add deadlines and exam dates** to my schedule so I can easily track important academic events.
* **Assignments**
    * As a student, I want to be able to **see a list of all my pending assignments** and their due dates so I can prioritize my workload.
    * As a student, I want to be able to **upload and submit my completed assignments** to the platform so my teacher can access them.
* **Attendance**
    * As a student, I want to be able to **fill in my attendance on a digital list** so my presence in a class is recorded accurately.
* **Notes and Study**
    * As a student, I want to be able to **create, edit, and save notes** on the platform so I can keep my study materials organized.
    * As a student, I want to be able to **summarize a long text document** into key points so I can quickly review essential information for a test.
    * As a student, I want to be able to get **help with possible exam questions** on a given topic so I can practice and prepare for my exams.

#### **As a Teacher**

* **Assignments**
    * As a teacher, I want to be able to **create and upload new assignments** with descriptions and due dates so students know what they need to do.
    * As a teacher, I want to be able to **view and download assignments** submitted by my students so I can grade them.
* **Attendance**
    * As a teacher, I want to be able to **create and upload a digital attendance list** for each of my classes.
    * As a teacher, I want to be able to **view and export the attendance data** for my classes so I have a record of student participation.

#### **As a System Administrator (or Developer)**

* As a system administrator, I want to be able to **manage user accounts** (both students and teachers) so I can add, remove, or modify their access.
* As a system administrator, I want to ensure the **system is secure and scalable** to handle a large number of users and concurrent activities.
* As a system administrator, I want to be able to **back up and restore data** so that user information and files are safe.

## Database Schema for UniHub

The tables for UniHub would be designed to represent the relationships between users, assignments, schedules, and notes. The following tables and their relationships reflect the core functionalities of the project. This is a simplified view of the **Entity-Relationship (ER) diagram** for the project.

***

### 1. `users` Table

This is the central table for user authentication and information. It will differentiate between students and teachers.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each user. |
| **`first_name`** | `string` | `NOT NULL` | The user's first name. |
| **`last_name`** | `string` | `NOT NULL` | The user's last name. |
| **`email`** | `string` | `NOT NULL`, `Unique` | User's email address, used for login. |
| **`password_digest`** | `string` | `NOT NULL` | Securely hashed password. |
| **`role`** | `string` | `NOT NULL` | Defines the user type: `student` or `teacher`. |
| **`created_at`** | `datetime` | `NOT NULL` | Timestamp of user creation. |
| **`updated_at`** | `datetime` | `NOT NULL` | Timestamp of last update. |

---

### 2. `assignments` Table

This table stores information about all assignments created by teachers.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each assignment. |
| **`teacher_id`** | `integer` | `Foreign Key` | Links the assignment to the **teacher** who created it. |
| **`title`** | `string` | `NOT NULL` | The title of the assignment. |
| **`description`** | `text` | | Detailed description of the assignment. |
| **`due_date`** | `datetime` | `NOT NULL` | The deadline for the assignment. |
| **`created_at`** | `datetime` | `NOT NULL` | Timestamp of assignment creation. |
| **`updated_at`** | `datetime` | `NOT NULL` | Timestamp of last update. |

---

### 3. `submissions` Table

This table records student submissions for assignments.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each submission. |
| **`student_id`** | `integer` | `Foreign Key` | Links the submission to the **student**. |
| **`assignment_id`** | `integer` | `Foreign Key` | Links the submission to the **assignment**. |
| **`file_url`** | `string` | `NOT NULL` | URL or path to the submitted file. |
| **`submitted_at`** | `datetime` | `NOT NULL` | The timestamp of the submission. |

---

### 4. `schedules` Table

This table allows students to create and manage their personal schedules.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each schedule entry. |
| **`student_id`** | `integer` | `Foreign Key` | Links the schedule entry to the **student**. |
| **`title`** | `string` | `NOT NULL` | Name of the class or event. |
| **`start_time`** | `datetime` | `NOT NULL` | The starting time of the event. |
| **`end_time`** | `datetime` | `NOT NULL` | The ending time of the event. |
| **`day_of_week`** | `string` | `NOT NULL` | The day of the week for the event (e.g., "Monday"). |

---

### 5. `attendance_lists` Table

This table represents a single attendance list created by a teacher for a specific class or event.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each attendance list. |
| **`teacher_id`** | `integer` | `Foreign Key` | Links the list to the **teacher**. |
| **`title`** | `string` | `NOT NULL` | Name of the class or event (e.g., "History 101 - 04/23/2025"). |
| **`list_date`** | `date` | `NOT NULL` | The date of the attendance list. |

---

### 6. `attendance_records` Table

This table stores the attendance record for each student on a given list.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each attendance record. |
| **`attendance_list_id`** | `integer` | `Foreign Key` | Links the record to the **attendance list**. |
| **`student_id`** | `integer` | `Foreign Key` | Links the record to the **student**. |
| **`status`** | `string` | `NOT NULL` | The attendance status (`present`, `absent`, `late`). |
| **`created_at`** | `datetime` | `NOT NULL` | Timestamp when the record was created. |

---

### 7. `notes` Table

This table will store all notes created by students.

| Column Name | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| **`id`** | `integer` | `Primary Key` | Unique identifier for each note. |
| **`student_id`** | `integer` | `Foreign Key` | Links the note to the **student**. |
| **`title`** | `string` | `NOT NULL` | The title of the note. |
| **`content`** | `text` | `NOT NULL` | The body of the note. |
| **`created_at`** | `datetime` | `NOT NULL` | Timestamp of note creation. |
| **`updated_at`** | `datetime` | `NOT NULL` | Timestamp of last update. |



This table structure provides a solid foundation for the UniHub application. It establishes clear relationships between users, their activities (assignments, schedules), and the content they create (notes, attendance).
