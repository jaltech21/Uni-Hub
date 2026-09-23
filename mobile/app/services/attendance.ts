/**
 * Attendance Service
 * Teachers create attendance lists (codes generated server-side, serialized
 * only for teachers); students mark themselves present with a code.
 */

import apiClient from "@services/api";
import { AttendanceList, AttendanceRecord } from "@app/types";

export interface AttendanceListCreatePayload {
  title: string;
  description?: string;
  date: string;
  schedule_id?: number;
}

class AttendanceService {
  async lists(): Promise<AttendanceList[]> {
    return apiClient.get<AttendanceList[]>("/attendance_lists");
  }

  async createList(payload: AttendanceListCreatePayload): Promise<AttendanceList> {
    return apiClient.post<AttendanceList>("/attendance_lists", {
      attendance_list: payload,
    });
  }

  async records(): Promise<AttendanceRecord[]> {
    return apiClient.get<AttendanceRecord[]>("/attendance_records");
  }

  async mark(attendanceListId: number, code: string): Promise<AttendanceRecord> {
    return apiClient.post<AttendanceRecord>("/attendance_records", {
      attendance_list_id: attendanceListId,
      code,
    });
  }
}

export default new AttendanceService();