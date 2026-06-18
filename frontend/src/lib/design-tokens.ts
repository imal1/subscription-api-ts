// Botanical Garden design tokens
// Core palette from theme-factory, extended with derived shades

export const tokens = {
  color: {
    // Core botanical palette
    fern: '#4a7c59',
    fernLight: '#8faa95',
    fernDark: '#2d4f37',
    fernPale: '#e8f0ea',

    marigold: '#f9a620',
    marigoldLight: '#fcd77d',
    marigoldDark: '#d4890f',

    terracotta: '#b7472a',
    terracottaLight: '#e88b74',

    cream: '#f5f3ed',
    creamLight: '#fafaf8',
    creamDark: '#e8e4db',

    // Neutrals
    ink: '#1a1d1a',
    inkLight: '#4a504a',
    stone: '#8a908a',

    // Dark mode surfaces
    darkBg: '#1a221c',
    darkSurface: '#222b25',
    darkElevated: '#2a342d',
    darkBorder: '#374038',

    // Semantic
    success: '#4a7c59',
    warning: '#f9a620',
    danger: '#b7472a',
    info: '#5b8c9e',
  },

  typography: {
    display: 'Georgia, "Times New Roman", serif',
    body: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    mono: '"JetBrains Mono", "SF Mono", "Cascadia Code", monospace',
  },

  radius: {
    sm: '6px',
    md: '12px',
    lg: '16px',
    xl: '24px',
  },

  shadow: {
    card: '0 1px 3px rgba(26, 29, 26, 0.06)',
    cardHover: '0 4px 16px rgba(26, 29, 26, 0.10)',
    elevated: '0 8px 30px rgba(26, 29, 26, 0.12)',
  },

  animation: {
    breathe: 'breathe 3s ease-in-out infinite',
    slideUp: 'slideUp 0.4s cubic-bezier(0.16, 1, 0.3, 1)',
    fadeIn: 'fadeIn 0.3s ease-out',
    growLine: 'growLine 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards',
  },
} as const;
