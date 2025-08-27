// src/test/mocks/mockData.ts
export const mockDuplicates = [
  {
    status: "Pending Review",
    score: 70,
    id: "a01gL00000Iw4GzQAJ",
    customerB: {
      phone: "11999999999",
      lastName: "Silva",
      isDeleted: false,
      id: "a00gL00000GrQkkQAF",
      firstName: "João",
      email: "j.silva@test.com"
    },
    customerA: {
      phone: "11999999999",
      lastName: "Silva",
      isDeleted: false,
      id: "a00gL00000GrQkjQAF",
      firstName: "João",
      email: "joao.silva@test.com"
    },
    createdAt: "2025-08-27T13:42:37.000Z"
  },
  {
    status: "Pending Review",
    score: 50,
    id: "a01gL00000IJa5TQAT",
    customerB: {
      phone: "555-5678",
      lastName: "D",
      isDeleted: false,
      id: "a00gL00000FjcP2QAJ",
      firstName: "Jane",
      email: "j.doe@example.com"
    },
    customerA: {
      phone: "555-5678",
      lastName: "Doe",
      isDeleted: false,
      id: "a00gL00000FjcP1QAJ",
      firstName: "Jane",
      email: "jane.doe@example.com"
    },
    createdAt: "2025-08-22T22:49:23.000Z"
  },
  {
    status: "Pending Review",
    score: 85,
    id: "a01gL00000Test001",
    customerB: {
      phone: "123-456-7890",
      lastName: "Johnson",
      isDeleted: false,
      id: "a00gL00000Test002",
      firstName: "Mike",
      email: "m.johnson@test.com"
    },
    customerA: {
      phone: "123-456-7890",
      lastName: "Johnson",
      isDeleted: false,
      id: "a00gL00000Test001",
      firstName: "Michael",
      email: "michael.johnson@test.com"
    },
    createdAt: "2025-08-20T10:15:30.000Z"
  }
]

export const createMergeResponse = (matchId: string, action: string) => ({
  survivingCustomer: "a00gL00000FjcP1QAJ",
  status: "success",
  message: action === "merge" 
    ? "Customer successfully merged via soft delete"
    : "Duplicate match ignored successfully",
  mergedCustomer: action === "merge" ? "a00gL00000FjcP2QAJ" : undefined,
  id: matchId,
  action
})