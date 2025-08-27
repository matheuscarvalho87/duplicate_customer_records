import { screen, waitFor } from '@testing-library/react'
import { expect } from 'vitest'

export const assertions = {
  async expectElementToBeVisible(text: string | RegExp) {
    const element = await screen.findByText(text)
    expect(element).toBeVisible()
    return element
  },

  async expectButtonToBeEnabled(name: string | RegExp) {
    const button = screen.getByRole('button', { name })
    await waitFor(() => expect(button).toBeEnabled())
    return button
  },

  async expectButtonToBeDisabled(name: string | RegExp) {
    const button = screen.getByRole('button', { name })
    await waitFor(() => expect(button).toBeDisabled())
    return button
  },

  async expectTableToHaveRows(count: number) {
    const rows = await screen.findAllByRole('row')
    expect(rows).toHaveLength(count + 1) // +1 for header row
    return rows
  },

  async expectErrorMessage(message: string | RegExp) {
    const errorElement = await screen.findByRole('alert')
    expect(errorElement).toHaveTextContent(message)
    return errorElement
  },

  async expectSuccessMessage(message: string | RegExp) {
    const successElement = await screen.findByText(message)
    expect(successElement).toBeInTheDocument()
    return successElement
  },

  expectScoreColor(score: number) {
    if (score >= 80) return 'bg-red-100'
    if (score >= 60) return 'bg-orange-100'
    return 'bg-yellow-100'
  }
}