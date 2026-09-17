/**
 * Folder Service
 * CRUD for organizing notes.
 */

import apiClient from "@services/api";
import { Folder } from "@app/types";

class FolderService {
  async list(): Promise<Folder[]> {
    return apiClient.get<Folder[]>("/folders");
  }

  async create(name: string, description?: string): Promise<Folder> {
    return apiClient.post<Folder>("/folders", { folder: { name, description } });
  }

  async update(id: number, patch: Partial<Pick<Folder, "name"> & { description?: string }>): Promise<Folder> {
    return apiClient.patch<Folder>(`/folders/${id}`, { folder: patch });
  }

  async remove(id: number): Promise<void> {
    return apiClient.delete(`/folders/${id}`);
  }
}

export default new FolderService();