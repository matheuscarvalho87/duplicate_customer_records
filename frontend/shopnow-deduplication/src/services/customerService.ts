import { http } from "../api/client";
import type { ApiResponse } from "../types/ApiResponse";
import type { Customer } from "../types/Customer";
import type { Pagination } from "../types/Pagination";

export const customerService = {
  async list(params?: { page?: number; pageSize?: number; search?: string }) {
    const { data } = await http.get<ApiResponse<{ items: Customer[]; pagination?: Pagination }>>(
      "/customers",
      { params },
    );
    return data.data;
  },

  async getById(id: string): Promise<Customer> {
    const { data } = await http.get<ApiResponse<Customer>>(`/customers/${encodeURIComponent(id)}`);
    return data.data;
  },
};
