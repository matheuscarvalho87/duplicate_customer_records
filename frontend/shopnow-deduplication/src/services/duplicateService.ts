import { http } from "../api/client";
import type { ApiResponse } from "../types/ApiResponse";
import type { DuplicateMatch } from "../types/DuplicateMatch";

export const duplicateService = {
  async getPending(): Promise<DuplicateMatch[]> {
    const { data } = await http.get<ApiResponse<DuplicateMatch[]>>("/duplicates/pending");
    return data.data;
  },

  async resolve(id: string, action: "merge" | "ignore"): Promise<void> {
    await http.post(`/duplicates/${encodeURIComponent(id)}/resolve`, { action });
  },
};
