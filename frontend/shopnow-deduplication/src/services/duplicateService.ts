import { http } from "../api/client";
import type { DuplicateMatch } from "../types/DuplicateMatch";
import type { Pagination } from "../types/Pagination";

interface SalesforcePagedResponse<T> {
  page: {
    total: number;
    offset: number;
    limit: number;
  };
  items: T[];
}

interface DuplicateListParams {
  limit?: number;
  offset?: number;
  minScore?: number;
  sort?: 'score' | 'createdAt' | 'status';
  order?: 'asc' | 'desc';
}

export const duplicateService = {

  async getPending(params?: DuplicateListParams): Promise<{
    duplicates: DuplicateMatch[];
    pagination: Pagination;
  }> {
    try {
      const queryParams = new URLSearchParams();
      
      const limit = params?.limit ?? 50;
      const offset = params?.offset ?? 0;
      const minScore = params?.minScore ?? 0;
      const sort = params?.sort ?? 'score';
      const order = params?.order ?? 'desc';
      
      queryParams.append('limit', limit.toString());
      queryParams.append('offset', offset.toString());
      queryParams.append('minScore', minScore.toString());
      queryParams.append('sort', sort);
      queryParams.append('order', order);

      const { data } = await http.get<SalesforcePagedResponse<DuplicateMatch>>(
        `/services/apexrest/duplicates/pending?${queryParams.toString()}`
      );

      return {
        duplicates: data.items || [],
        pagination: {
          page: Math.floor(data.page.offset / data.page.limit) + 1,
          pageSize: data.page.limit,
          total: data.page.total
        }
      };
    } catch (error) {
      console.error('Error fetching pending duplicates:', error);
      throw error;
    }
  },

  async getPendingSimple(): Promise<DuplicateMatch[]> {
    const result = await this.getPending({ limit: 1000 });
    return result.duplicates;
  },


  async resolve(id: string, action: "merge" | "ignore"): Promise<void> {
    try {
      await http.post(`/services/apexrest/duplicates/${encodeURIComponent(id)}/resolve`, { 
        action 
      });
    } catch (error) {
      console.error(`Error resolving duplicate ${id} with action ${action}:`, error);
      throw error;
    }
  }
};