/**
 * Announcement Service
 * Fetches published announcements for the current user's department.
 */

import apiClient from "@services/api";
import { Announcement } from "@app/types";

class AnnouncementService {
  async list(): Promise<Announcement[]> {
    return apiClient.get<Announcement[]>("/announcements");
  }

  async get(id: number): Promise<Announcement> {
    return apiClient.get<Announcement>(`/announcements/${id}`);
  }
}

export default new AnnouncementService();