"use client";

import { useId, useState, type InputHTMLAttributes } from "react";
import { Icon } from "@/components/ui/Icon";

interface InputFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "id"> {
  label: string;
  icon?: string; // Icon name registered in Icon.tsx (e.g., 'mail')
  id?: string;
}

// Labeled input with optional left icon.
// When type="password" it automatically gets a show/hide toggle.
export function InputField({
  label,
  icon,
  type = "text",
  id,
  className = "",
  ...props
}: InputFieldProps) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const isPassword = type === "password";
  const [visible, setVisible] = useState(false);

  return (
    <div>
      <label htmlFor={inputId} className="mb-1.5 block text-sm font-medium text-slate-700">
        {label}
      </label>

      <div className="relative">
        {icon && (
          <Icon
            name={icon}
            className="pointer-events-none absolute left-3 top-1/2 size-4.5 -translate-y-1/2 text-slate-400"
          />
        )}

        <input
          id={inputId}
          type={isPassword && visible ? "text" : type}
          className={`block w-full rounded-xl border border-slate-200 bg-slate-50 py-2.5 text-sm placeholder-slate-400 transition-all focus:border-blue-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500 ${
            icon ? "pl-10" : "pl-3"
          } ${isPassword ? "pr-10" : "pr-3"} ${className}`}
          {...props}
        />

        {isPassword && (
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? "Hide password" : "Show password"}
            className="absolute inset-y-0 right-0 flex items-center pr-3 text-slate-400 hover:text-slate-600 focus:outline-none"
          >
            <Icon name={visible ? "visibility_off" : "visibility"} className="size-4.5" />
          </button>
        )}
      </div>
    </div>
  );
}
