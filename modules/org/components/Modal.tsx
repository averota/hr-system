// modules/org/components/Modal.tsx
"use client";

import { useId, type ReactNode } from "react";

interface ModalProps {
  title: string;
  children: ReactNode;
  submitLabel: string;
  canSubmit: boolean;
  isSaving: boolean;
  error: string | null;
  onSubmit: () => void;
  onCancel: () => void;
}

/** Shared modal frame: title, content, error line, Cancel and submit buttons. */
export function Modal({
  title,
  children,
  submitLabel,
  canSubmit,
  isSaving,
  error,
  onSubmit,
  onCancel,
}: ModalProps) {
  const titleId = useId();

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
    >
      <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-lg">
        <h3 id={titleId} className="text-base font-semibold text-zinc-900">
          {title}
        </h3>

        {children}

        {error && (
          <p role="alert" className="mt-3 text-xs text-red-700">
            {error}
          </p>
        )}

        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={isSaving}
            className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onSubmit}
            disabled={!canSubmit || isSaving}
            className="rounded-md bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-zinc-800 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600"
          >
            {isSaving ? "Saving..." : submitLabel}
          </button>
        </div>
      </div>
    </div>
  );
}