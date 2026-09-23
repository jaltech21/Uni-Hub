/**
 * Admin Service
 * Role-gated admin panel endpoints (Dashboard, Users, Departments, Courses, Schedules, Announcements).
 */

import apiClient from "@services/api";
import { AdminUser, Announcement, Course, Department, Schedule } from "@app/types";

export interface AdminDashboard {
  users_count: number;
  students_count: number;
  teachers_count: number;
  admins_count: number;
  courses_count: number;
  active_courses_count: number;
  schedules_count: number;
  enrollments_count: number;
  departments_count: number;
  blacklisted_users_count: number;
}

class AdminService {
  async dashboard(): Promise<AdminDashboard> {
    return apiClient.get<AdminDashboard>("/admin/dashboard");
  }

  async listUsers(params?: {
    role?: string;
    department_id?: number;
    search?: string;
    page?: number;
  }): Promise<AdminUser[]> {
    return apiClient.get<AdminUser[]>("/admin/users", { params });
  }

  async updateUser(id: number, patch: Partial<AdminUser>): Promise<AdminUser> {
    return apiClient.patch<AdminUser>(`/admin/users/${id}`, { user: patch });
  }

  async changeUserRole(id: number, role: string): Promise<AdminUser> {
    return apiClient.patch<AdminUser>(`/admin/users/${id}/change_role`, { role });
  }

  async blacklistUser(id: number, reason: string): Promise<AdminUser> {
    return apiClient.patch<AdminUser>(`/admin/users/${id}/blacklist`, { reason });
  }

  async unblacklistUser(id: number): Promise<AdminUser> {
    return apiClient.patch<AdminUser>(`/admin/users/${id}/unblacklist`);
  }

  async listDepartments(): Promise<Department[]> {
    return apiClient.get<Department[]>("/admin/departments");
  }

  async createDepartment(data: Partial<Department>): Promise<Department> {
    return apiClient.post<Department>("/admin/departments", { department: data });
  }

  async updateDepartment(id: number, patch: Partial<Department>): Promise<Department> {
    return apiClient.patch<Department>(`/admin/departments/${id}`, { department: patch });
  }

  async deleteDepartment(id: number): Promise<void> {
    return apiClient.delete(`/admin/departments/${id}`);
  }

  async toggleDepartmentActive(id: number): Promise<Department> {
    return apiClient.patch<Department>(`/admin/departments/${id}/toggle_active`);
  }

  async listCourses(departmentId?: number): Promise<Course[]> {
    return apiClient.get<Course[]>("/admin/courses", { params: { department_id: departmentId } });
  }

  async createCourse(data: Partial<Course>): Promise<Course> {
    return apiClient.post<Course>("/admin/courses", { course: data });
  }

  async updateCourse(id: number, patch: Partial<Course>): Promise<Course> {
    return apiClient.patch<Course>(`/admin/courses/${id}`, { course: patch });
  }

  async deleteCourse(id: number): Promise<void> {
    return apiClient.delete(`/admin/courses/${id}`);
  }

  async toggleCourseActive(id: number): Promise<Course> {
    return apiClient.patch<Course>(`/admin/courses/${id}/toggle_active`);
  }

  async listSchedules(): Promise<Schedule[]> {
    return apiClient.get<Schedule[]>("/admin/schedules");
  }

  async createSchedule(data: Record<string, unknown>): Promise<Schedule> {
    return apiClient.post<Schedule>("/admin/schedules", { schedule: data });
  }

  async updateSchedule(id: number, patch: Record<string, unknown>): Promise<Schedule> {
    return apiClient.patch<Schedule>(`/admin/schedules/${id}`, { schedule: patch });
  }

  async deleteSchedule(id: number): Promise<void> {
    return apiClient.delete(`/admin/schedules/${id}`);
  }

  async approveSchedule(id: number): Promise<Schedule> {
    return apiClient.post<Schedule>(`/admin/schedules/${id}/approve`);
  }

  async cancelSchedule(id: number): Promise<Schedule> {
    return apiClient.post<Schedule>(`/admin/schedules/${id}/cancel`);
  }

  async listAnnouncements(): Promise<Announcement[]> {
    return apiClient.get<Announcement[]>("/admin/announcements");
  }

  async createAnnouncement(data: Partial<Announcement>): Promise<Announcement> {
    return apiClient.post<Announcement>("/admin/announcements", { announcement: data });
  }

  async updateAnnouncement(id: number, patch: Partial<Announcement>): Promise<Announcement> {
    return apiClient.patch<Announcement>(`/admin/announcements/${id}`, { announcement: patch });
  }

  async deleteAnnouncement(id: number): Promise<void> {
    return apiClient.delete(`/admin/announcements/${id}`);
  }

  async publishAnnouncement(id: number): Promise<Announcement> {
    return apiClient.patch<Announcement>(`/admin/announcements/${id}/publish`);
  }

  async unpublishAnnouncement(id: number): Promise<Announcement> {
    return apiClient.patch<Announcement>(`/admin/announcements/${id}/unpublish`);
  }
}

export default new AdminService();