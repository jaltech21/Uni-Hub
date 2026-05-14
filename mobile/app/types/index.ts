/**
 * Type definitions for UniHub Mobile App
 */

export interface User {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  role: "student" | "teacher" | "admin";
  department_id: number;
  profile_picture_url?: string;
  created_at: string;
  updated_at: string;
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
  teacher_id: number;
  created_at: string;
  updated_at: string;
}

export interface Submission {
  id: number;
  student_id: number;
  assignment_id: number;
  file_url: string;
  submitted_at: string;
}

export interface Schedule {
  id: number;
  title: string;
  start_time: string;
  end_time: string;
  day_of_week: string;
  student_id: number;
}

export interface AttendanceList {
  id: number;
  teacher_id: number;
  title: string;
  list_date: string;
}

export interface AttendanceRecord {
  id: number;
  attendance_list_id: number;
  student_id: number;
  status: "present" | "absent" | "late";
  created_at: string;
}

export interface Message {
  id: number;
  sender_id: number;
  recipient_id: number;
  content: string;
  created_at: string;
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
