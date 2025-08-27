import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect } from 'vitest'

export const userInteractions = {
  async clickButton(name: string | RegExp) {
    const button = screen.getByRole('button', { name })
    await userEvent.click(button)
    return button
  },

  async clickByText(text: string | RegExp) {
    const element = screen.getByText(text)
    await userEvent.click(element)
    return element
  },

  async fillInput(labelText: string | RegExp, value: string) {
    const input = screen.getByLabelText(labelText)
    await userEvent.clear(input)
    await userEvent.type(input, value)
    return input
  },

  async selectOption(labelText: string | RegExp, option: string) {
    const select = screen.getByLabelText(labelText)
    await userEvent.selectOptions(select, option)
    return select
  },

  async waitForElementToDisappear(text: string | RegExp) {
    await screen.findByText(text)
    await expect(screen.queryByText(text)).not.toBeInTheDocument()
  },

  async waitForLoadingToFinish() {
    const loadingElements = screen.queryAllByText(/loading/i)
    if (loadingElements.length > 0) {
      await Promise.all(
        loadingElements.map(el => 
          expect(el).not.toBeInTheDocument()
        )
      )
    }
  }
}