/**
 * Home Service
 * Fetches live dashboard stats for the Home screen.
 */

import apiClient from "@services/api";
import { HomeStats } from "@app/types";

class HomeService {
  async stats(): Promise<HomeStats> {
    return apiClient.get<HomeStats>("/home/stats");
  }
}

export default new HomeService();