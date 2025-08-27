import type { DuplicateMatch } from '../../types/DuplicateMatch'
import type { Customer } from '../../types/Customer'

export const customerFactory = {
  build(overrides: Partial<Customer> = {}): Customer {
    return {
      id: 'a00gL00000TestID',
      firstName: 'Test',
      lastName: 'User',
      email: 'test.user@example.com',
      phone: '555-0123',
      isDeleted: false,
      ...overrides,
    }
  },

  buildMany(count: number, overrides: Partial<Customer> = {}): Customer[] {
    return Array.from({ length: count }, (_, index) =>
      this.build({
        id: `a00gL0000000${index.toString().padStart(3, '0')}`,
        firstName: `User${index}`,
        email: `user${index}@example.com`,
        ...overrides,
      })
    )
  },
}

export const duplicateFactory = {
  build(overrides: Partial<DuplicateMatch> = {}): DuplicateMatch {
    return {
      id: 'a01gL00000TestDup',
      score: 75,
      status: 'Pending Review',
      createdAt: new Date().toISOString(),
      customerA: customerFactory.build({ id: 'a00gL00000TestA' }),
      customerB: customerFactory.build({ id: 'a00gL00000TestB' }),
      ...overrides,
    }
  },

  buildMany(count: number, overrides: Partial<DuplicateMatch> = {}): DuplicateMatch[] {
    return Array.from({ length: count }, (_, index) =>
      this.build({
        id: `a01gL0000000${index.toString().padStart(3, '0')}`,
        score: Math.floor(Math.random() * 100),
        customerA: customerFactory.build({ id: `a00gL000A${index.toString().padStart(3, '0')}` }),
        customerB: customerFactory.build({ id: `a00gL000B${index.toString().padStart(3, '0')}` }),
        ...overrides,
      })
    )
  },

  buildHighScore(overrides: Partial<DuplicateMatch> = {}): DuplicateMatch {
    return this.build({ score: 95, ...overrides })
  },

  buildLowScore(overrides: Partial<DuplicateMatch> = {}): DuplicateMatch {
    return this.build({ score: 35, ...overrides })
  },
}