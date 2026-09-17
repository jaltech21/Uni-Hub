/**
 * Enrollment Service
 * Student enrollment management.
 */

import apiClient from "@services/api";
import { Enrollment } from "@app/types";

class EnrollmentService {
  async list(): Promise<Enrollment[]> {
    return apiClient.get<Enrollment[]>("/enrollments");
  }

  async create(scheduleId: number): Promise<Enrollment> {
    return apiClient.post<Enrollment>("/enrollments", {
      enrollment: { schedule_id: scheduleId },
    });
  }

  async remove(id: number): Promise<void> {
    return apiClient.delete(`/enrollments/${id}`);
  }

  async capacity(scheduleId: number): Promise<{
    enrolled: number;
    available_slots: number;
    has_capacity: boolean;
  }> {
    return apiClient.get(`/enrollments/capacity/${scheduleId}`);
  }
}

export default new EnrollmentService();