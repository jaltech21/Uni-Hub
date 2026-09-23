/**
 * Assignment Service
 * Lists assignments, handles student submissions, and supports teacher
 * create/grade workflows.
 */

import apiClient from "@services/api";
import { Assignment, AssignmentCreatePayload, Submission } from "@app/types";

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

  async create(payload: AssignmentCreatePayload): Promise<Assignment> {
    return apiClient.post<Assignment>("/assignments", { assignment: payload });
  }

  async submissions(id: number): Promise<Submission[]> {
    return apiClient.get<Submission[]>(`/assignments/${id}/submissions`);
  }

  async grade(submissionId: number, grade: number, feedback?: string): Promise<Submission> {
    return apiClient.post<Submission>(`/submissions/${submissionId}/grade`, {
      submission: { grade, feedback },
    });
  }
}

export default new AssignmentService();