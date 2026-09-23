/**
 * Schedule Service
 * Fetches schedules and manages student enrollment.
 */

import apiClient from "@services/api";
import { Enrollment, Schedule, ScheduleCreatePayload } from "@app/types";

class ScheduleService {
  async list(): Promise<Schedule[]> {
    return apiClient.get<Schedule[]>("/schedules");
  }

  async get(id: number): Promise<Schedule> {
    return apiClient.get<Schedule>(`/schedules/${id}`);
  }

  async create(data: ScheduleCreatePayload): Promise<Schedule> {
    return apiClient.post<Schedule>("/schedules", data);
  }

  async browse(): Promise<Schedule[]> {
    return apiClient.get<Schedule[]>("/schedules/browse");
  }

  async enroll(scheduleId: number): Promise<Enrollment> {
    return apiClient.post<Enrollment>(`/schedules/${scheduleId}/enroll`);
  }

  async unenroll(scheduleId: number): Promise<void> {
    return apiClient.delete(`/schedules/${scheduleId}/unenroll`);
  }
}

export default new ScheduleService();