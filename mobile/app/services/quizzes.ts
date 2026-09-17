/**
 * Quiz Service
 * Lists quizzes, submits answers and fetches results.
 */

import apiClient from "@services/api";
import { Quiz } from "@app/types";

export interface QuizResults {
  attempt_id: number;
  score: number;
  correct_answers: number;
  total_questions: number;
  passed: boolean;
}

class QuizService {
  async list(): Promise<Quiz[]> {
    return apiClient.get<Quiz[]>("/quizzes");
  }

  async get(id: number): Promise<Quiz> {
    return apiClient.get<Quiz>(`/quizzes/${id}`);
  }

  async submit(id: number, answers: Record<string, string>): Promise<QuizResults> {
    return apiClient.post<QuizResults>(`/quizzes/${id}/submit`, { answers });
  }

  async results(id: number): Promise<QuizResults> {
    return apiClient.get<QuizResults>(`/quizzes/${id}/results`);
  }
}

export default new QuizService();