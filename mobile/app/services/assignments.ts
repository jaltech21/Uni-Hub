/**
 * Assignment Service
 * Lists assignments and handles student submissions.
 */

import apiClient from "@services/api";
import { Assignment, Submission } from "@app/types";

class AssignmentService {
  async list(): Promise<Assignment[]> {
    return apiClient.get<Assignment[]>("/assignments");
  }

  async get(id: number): Promise<Assignment> {
    return apiClient.get<Assignment>(`/assignments/${id}`);
  }

  async mySubmissions(): Promise<Submission[]> {
    return apiClient.get<Submission[]>("/assignments/my_submissions");
  }

  async submit(id: number, content: string): Promise<Submission> {
    return apiClient.post<Submission>(`/assignments/${id}/submit`, {
      submission: { content },
    });
  }
}

export default new AssignmentService();