/**
 * Type definitions for UniHub Mobile App
 */

export interface User {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  username?: string;
  role: "student" | "teacher" | "tutor" | "admin";
  department_id: number;
  profile_picture_url?: string;
  created_at: string;
  updated_at: string;
}

export function userIsAdmin(user: User | null): boolean {
  return Boolean(user && user.role === "admin");
}

export function userIsTeacher(user: User | null): boolean {
  return Boolean(user && (user.role === "teacher" || user.role === "tutor"));
}

export function userIsStudent(user: User | null): boolean {
  return Boolean(user && user.role === "student");
}

export interface AuthState {
  user: User | null;
  token: string | null;
  loading: boolean;
  error: string | null;
}

export interface Note {
  id: number;
  title: string;
  content: string;
  student_id: number;
  created_at: string;
  updated_at: string;
}

export interface Assignment {
  id: number;
  title: string;
  description: string;
  due_date: string;
  points?: number;
  category?: string;
  grading_criteria?: string;
  allow_resubmission?: boolean;
  teacher_id: number;
  course_id?: number;
  course_name?: string;
  status?: "pending" | "submitted" | "graded";
  created_at: string;
  updated_at: string;
}

export interface AssignmentCreatePayload {
  title: string;
  description: string;
  due_date: string;
  points: number;
  category: string;
  grading_criteria?: string;
  allow_resubmission?: boolean;
  course_name?: string;
  schedule_id?: number;
}

export interface Submission {
  id: number;
  student_id: number;
  student_name?: string;
  assignment_id: number;
  content?: string;
  file_url?: string;
  grade?: number | null;
  feedback?: string | null;
  status?: string;
  submitted_at: string;
  graded_at?: string | null;
}

export interface Schedule {
  id: number;
  title: string;
  start_time: string;
  end_time: string;
  day_of_week: string;
  day_name?: string;
  student_id: number;
  course_id?: number;
  course_name?: string;
  location?: string;
  instructor_name?: string;
  status?: "pending" | "approved" | "cancelled";
  description?: string;
  recurring?: boolean;
}

export interface ScheduleCreatePayload {
  title: string;
  course?: string;
  day_of_week: number | string;
  start_time: string;
  end_time: string;
  room?: string;
  description?: string;
  color?: string;
  recurring?: boolean;
}

export interface Enrollment {
  id: number;
  student_id: number;
  schedule_id: number;
  schedule_title?: string;
  created_at: string;
}

export interface Message {
  id: number;
  sender_id: number;
  recipient_id: number;
  content: string;
  read: boolean;
  sender_name?: string;
  recipient_name?: string;
  created_at: string;
}

export interface Conversation {
  id: number;
  user: {
    id: number;
    name: string;
  };
  last_message: string | null;
  last_message_at: string | null;
  unread_count: number;
}

export interface Notification {
  id: number;
  title: string;
  body: string;
  read: boolean;
  notification_type?: string;
  action_url?: string | null;
  created_at: string;
}

export interface Announcement {
  id: number;
  title: string;
  content: string;
  priority: "low" | "normal" | "high" | "urgent";
  pinned: boolean;
  department_id: number;
  department_name?: string;
  author_name?: string;
  published_at?: string | null;
  expires_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface AttendanceList {
  id: number;
  teacher_id: number;
  title: string;
  description?: string | null;
  list_date: string;
  attendance_code?: string | null;
  schedule_id?: number | null;
}

export interface AttendanceRecord {
  id: number;
  attendance_list_id: number;
  list_title?: string;
  list_date?: string;
  student_id: number;
  student_name?: string;
  status: "present" | "absent" | "late";
  present?: boolean;
  created_at: string;
}

export interface Folder {
  id: number;
  name: string;
  parent_id?: number | null;
  created_at: string;
}

export interface Department {
  id: number;
  name: string;
  code?: string;
  active?: boolean;
  created_at: string;
}

export interface Course {
  id: number;
  name: string;
  code: string;
  department_id: number;
  active?: boolean;
  created_at: string;
}

export interface AdminUser extends User {
  department_name?: string;
  active: boolean;
}

export interface HomeStats {
  classes_today: number;
  assignments_due: number;
  notes_count: number;
  today_schedule: Schedule[];
  upcoming_tasks: Assignment[];
}

export interface Quiz {
  id: number;
  title: string;
  description: string;
  created_by: number;
  created_at: string;
  updated_at: string;
}

export interface QuizQuestion {
  id: number;
  quiz_id: number;
  question_text: string;
  question_type: "multiple_choice" | "fill_in" | "short_answer";
  options?: string[];
  correct_answer?: string;
}

export interface Summarization {
  id: number;
  original_text: string;
  summary_text: string;
  student_id: number;
  created_at: string;
}

export interface ApiError {
  status: number;
  message: string;
  errors?: Record<string, string[]>;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiError;
  message?: string;
}
