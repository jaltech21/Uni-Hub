/**
 * AI Service
 * Conversational UniHub AI assistant with persistent in-app history.
 */

import apiClient from "@services/api";

export interface AiMessage {
  id: number;
  role: "user" | "assistant";
  content: string;
  status?: string;
  tokens_used?: number | null;
  created_at?: string;
}

export interface AiProgress {
  status: "critical" | "warning" | "on_track";
  score: number;
  label: string;
  metrics: {
    upcoming_assignments: number;
    overdue_assignments: number;
    pending_submissions: number;
    average_grade: number | null;
    recent_notes: number;
    scheduled_classes: number;
  };
  upcoming?: Array<{ title: string; due_date: string; course: string }>;
}

class AiService {
  async history(): Promise<AiMessage[]> {
    const payload = await apiClient.get<{ messages?: AiMessage[] } | AiMessage[]>("/ai/chat");
    if (Array.isArray(payload)) {
      return payload;
    }
    return payload?.messages ?? [];
  }

  async send(message: string): Promise<{ message: AiMessage; messages: AiMessage[] }> {
    return apiClient.post<{ message: AiMessage; messages: AiMessage[] }>(
      "/ai/chat",
      { message },
      { timeout: 150000 }
    );
  }

  async clear(): Promise<void> {
    return apiClient.delete("/ai/chat");
  }

  async progress(): Promise<AiProgress> {
    return apiClient.get<AiProgress>("/ai/progress");
  }

  async tutorReport(): Promise<TutorReportEntry[]> {
    return apiClient.get<TutorReportEntry[]>("/ai/tutor_report");
  }
}

export interface TutorReportEntry {
  schedule_id: number;
  schedule_title?: string;
  schedule_title_raw?: string;
  course_code?: string;
  students: TutorReportStudent[];
}

export interface TutorReportStudent {
  student_id: number;
  student_name: string;
  assignments_count: number;
  submitted_count: number;
  graded_count: number;
  average_grade: number | null;
  progress_score: number;
}

export default new AiService();