// app/(auth)/login/LoginForm.tsx
"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/Button";
import { Icon } from "@/components/ui/Icon";
import { InputField } from "@/components/ui/InputField";
import { REMEMBER_DAYS } from "@/lib/supabase/remember";
import { login, type LoginState } from "../actions";

const initialState: LoginState = { error: null };

export function LoginForm() {
  const [state, formAction, pending] = useActionState(login, initialState);

  return (
    <form action={formAction} className="space-y-5">
      <InputField
        label="Email"
        name="email"
        type="email"
        icon="mail"
        placeholder="name@company.com"
        autoComplete="email"
        autoCapitalize="none"
        spellCheck={false}
        defaultValue={state.email}
        required
      />

      <InputField
        label="Password"
        name="password"
        type="password"
        icon="lock"
        placeholder="••••••••"
        autoComplete="current-password"
        required
      />

      <div className="mt-4 flex items-center justify-between">
        <label className="flex cursor-pointer items-center text-sm text-slate-600">
          <input
            type="checkbox"
            name="remember-me"
            defaultChecked={state.remember}
            className="mr-2 h-4 w-4 cursor-pointer rounded border-slate-300 text-blue-600 focus:ring-blue-500"
          />
          Remember me for {REMEMBER_DAYS} days
        </label>
        {/* TODO: password reset flow not built yet */}
        <a href="#" className="text-sm font-medium text-blue-600 hover:text-blue-500 hover:underline">
          Forgot password?
        </a>
      </div>

      {state.error && (
        <div
          role="alert"
          className="flex items-start gap-2 rounded-xl border border-red-100 bg-red-50 px-3 py-2.5 text-sm text-red-700"
        >
          <Icon name="error" className="size-4.5" />
          <span>{state.error}</span>
        </div>
      )}

      <Button
        type="submit"
        size="lg"
        icon="arrow_forward"
        iconPosition="right"
        className="w-full"
        disabled={pending}
      >
        {pending ? "Signing in..." : "Sign in to workspace"}
      </Button>
    </form>
  );
}
