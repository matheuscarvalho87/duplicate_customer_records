import type { Customer } from "./Customer";

export type DuplicateStatus = "Pending Review" | "Merged" | "Ignored";

export type DuplicateMatch = {
  id: string;          
  customerA: Customer;
  customerB: Customer;
  score: number;   
  status: DuplicateStatus;
};
