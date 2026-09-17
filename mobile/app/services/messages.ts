/**
 * Message Service
 * Conversations, threads, composing and user search.
 */

import apiClient from "@services/api";
import { Conversation, Message } from "@app/types";

export interface SearchUser {
  id: number;
  name: string;
  email: string;
  department?: string | null;
}

class MessageService {
  async conversations(): Promise<Conversation[]> {
    return apiClient.get<Conversation[]>("/messages/conversations");
  }

  async thread(partnerId: number): Promise<Message[]> {
    return apiClient.get<Message[]>(`/messages/${partnerId}`);
  }

  async send(recipientId: number, content: string): Promise<Message> {
    return apiClient.post<Message>("/messages", {
      message: { recipient_id: recipientId, content },
    });
  }

  async markAsRead(partnerId: number): Promise<void> {
    return apiClient.post(`/messages/${partnerId}/mark_as_read`);
  }

  async searchUsers(query: string): Promise<SearchUser[]> {
    return apiClient.get<SearchUser[]>("/messages/search_users", {
      params: { q: query },
    });
  }
}

export default new MessageService();