"use client";

import { useTheme } from "./ThemeProvider";
import { Icon } from "@iconify/react";

export default function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();

  return (
    <button
      onClick={toggleTheme}
      className="relative inline-flex h-9 w-9 items-center justify-center rounded-2xl bg-[var(--surface-container)] text-[var(--muted-foreground)] transition-all duration-300 hover:bg-[var(--surface-container-high)] hover:text-[var(--foreground)]"
      aria-label={theme === "light" ? "切换到夜间模式" : "切换到日间模式"}
      title={theme === "light" ? "夜间模式" : "日间模式"}
    >
      <span
        className={`absolute transition-all duration-300 ${
          theme === "light"
            ? "opacity-100 rotate-0 scale-100"
            : "opacity-0 -rotate-90 scale-50"
        }`}
      >
        <Icon icon="ph:moon-bold" className="w-4 h-4" />
      </span>
      <span
        className={`absolute transition-all duration-300 ${
          theme === "dark"
            ? "opacity-100 rotate-0 scale-100"
            : "opacity-0 rotate-90 scale-50"
        }`}
      >
        <Icon icon="ph:sun-bold" className="w-4 h-4" />
      </span>
    </button>
  );
}
