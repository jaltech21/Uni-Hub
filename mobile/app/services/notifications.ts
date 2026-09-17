/**
 * Notification Service
 * Lists notifications and manages read state.
 */

import apiClient from "@services/api";
import { Notification } from "@app/types";

class NotificationService {
  async list(): Promise<Notification[]> {
    return apiClient.get<Notification[]>("/notifications");
  }

  async unreadCount(): Promise<number> {
    const payload = await apiClient.get<{ count: number }>("/notifications/unread_count");
    return payload.count;
  }

  async markAsRead(id: number): Promise<void> {
    return apiClient.post(`/notifications/${id}/mark_as_read`);
  }

  async markAllAsRead(): Promise<void> {
    return apiClient.post("/notifications/mark_all_as_read");
  }
}

export default new NotificationService();