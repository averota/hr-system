// app/(auth)/page.tsx
import type { Metadata } from "next";
import { BrandLogo } from "@/components/ui/BrandLogo";
import { Button } from "@/components/ui/Button";
import { Icon } from "@/components/ui/Icon";
import { inter } from "@/lib/fonts";

export const metadata: Metadata = {
  title: "NEXON Cloud | HRIS Platform",
  description:
    "The all-in-one HRIS platform designed to streamline human resources, payroll, and talent management.",
};

// TODO: placeholder marketing copy, replace with your real content.
const FEATURES = [
  {
    icon: "apartment",
    title: "Company Structure",
    description: "Model departments, branches and reporting lines in one place.",
  },
  {
    icon: "groups",
    title: "Employee Records",
    description: "Keep every profile, contract and document organized and easy to find.",
  },
  {
    icon: "event_note",
    title: "Leave Management",
    description: "Submit, review and track leave requests with a clear approval flow.",
  },
  {
    icon: "timer",
    title: "Overtime Rules",
    description: "Define overtime policies once and apply them consistently across teams.",
  },
  {
    icon: "payments",
    title: "Payroll",
    description: "Connect attendance, leave and overtime to payroll for a smoother month-end.",
  },
  {
    icon: "school",
    title: "Education & Training",
    description: "Track qualifications, certifications and learning records for your people.",
  },
];

export default function LandingPage() {
  // TEMP: [--color-primary:#2563eb] keeps bg-primary blue on this page only.
  // The current globals.css uses a near-black primary for the other pages.
  // Remove it once globals.css matches the reference.
  // min-h-dvh replaces the reference's min-h-workspace, which no globals.css defines.
  return (
    <div
      className={`${inter.className} flex min-h-dvh flex-col bg-white text-slate-900 [--color-primary:#2563eb]`}
    >
      {/* Top navigation */}
      <header className="sticky top-0 z-20 border-b border-slate-100 bg-white/80 backdrop-blur">
        <div className="mx-auto flex items-center justify-between px-6 py-4 lg:px-8">
          <BrandLogo />
          <nav className="flex items-center gap-6">
            <a
              href="#features"
              className="hidden text-sm font-medium text-slate-600 hover:text-blue-600 sm:block"
            >
              Features
            </a>
            <Button href="/login" icon="login">
              Log in
            </Button>
          </nav>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="bg-linear-to-b from-blue-50 to-white">
          <div className="mx-auto grid max-w-7xl items-center gap-12 px-6 py-16 lg:grid-cols-2 lg:px-8 lg:py-24">
            <div>
              <span className="mb-5 inline-flex items-center gap-1.5 rounded-full border border-blue-100 bg-white px-3 py-1 text-xs font-semibold text-blue-700">
                <Icon name="verified_user" className="size-3.5" />
                All-in-one HRIS platform
              </span>
              <h1 className="mb-6 text-4xl font-bold leading-tight tracking-tight sm:text-5xl lg:text-6xl">
                Empower your <span className="text-blue-600">workforce</span> today.
              </h1>
              <p className="mb-8 max-w-xl text-lg leading-relaxed text-slate-600">
                Streamline your human resources, payroll, and talent management in one secure,
                easy-to-use platform.
              </p>
              <div className="flex flex-wrap gap-3">
                <Button href="/login" size="lg" icon="arrow_forward" iconPosition="right">
                  Log in to workspace
                </Button>
                <Button href="#features" variant="outline" size="lg">
                  Explore features
                </Button>
              </div>
            </div>

            {/* Workspace preview (decorative) */}
            <div className="relative">
              <div className="absolute -inset-4 rounded-3xl bg-blue-600/10 blur-2xl" />
              <div className="relative rounded-3xl bg-blue-900 p-6 shadow-2xl shadow-blue-900/20">
                <p className="mb-4 text-sm font-semibold text-blue-100">Your workspace</p>
                <div className="grid grid-cols-2 gap-3">
                  {FEATURES.slice(0, 4).map((feature) => (
                    <div
                      key={feature.title}
                      className="rounded-2xl border border-white/20 bg-white/10 p-4 backdrop-blur-[10px]"
                    >
                      <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-linear-to-br from-blue-500 to-indigo-600 text-white shadow-lg shadow-blue-500/30">
                        <Icon name={feature.icon} className="size-5" />
                      </div>
                      <p className="text-sm font-semibold text-white">{feature.title}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Features */}
        <section id="features" className="mx-auto max-w-7xl scroll-mt-20 px-6 py-16 lg:px-8 lg:py-24">
          <div className="mx-auto mb-12 max-w-2xl text-center">
            <h2 className="mb-3 text-3xl font-bold tracking-tight">Everything your HR team needs</h2>
            <p className="text-slate-500">
              From the first day to payroll, manage the full employee journey from one workspace.
            </p>
          </div>

          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {FEATURES.map((feature) => (
              <div
                key={feature.title}
                className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
                  <Icon name={feature.icon} className="size-5" />
                </div>
                <h3 className="mb-1.5 text-base font-bold">{feature.title}</h3>
                <p className="text-sm leading-relaxed text-slate-500">{feature.description}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Call to action */}
        <section className="px-6 pb-16 lg:px-8 lg:pb-24">
          <div className="relative mx-auto max-w-5xl overflow-hidden rounded-3xl bg-blue-900 px-8 py-12 text-center">
            <div className="pointer-events-none absolute inset-0">
              <div className="absolute -left-[10%] -top-[40%] h-[120%] w-[50%] rounded-full bg-blue-600/30 blur-3xl" />
              <div className="absolute -bottom-[40%] -right-[10%] h-[120%] w-[40%] rounded-full bg-indigo-500/20 blur-3xl" />
            </div>
            <div className="relative">
              <h2 className="mb-3 text-3xl font-bold text-white">Ready to get started?</h2>
              <p className="mx-auto mb-8 max-w-xl text-blue-100">
                Log in to access your NEXON Cloud workspace.
              </p>
              <Button href="/login" size="lg" icon="arrow_forward" iconPosition="right">
                Log in to workspace
              </Button>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-slate-100">
        <div className="mx-auto flex flex-col items-center justify-center gap-3 px-6 py-6 sm:flex-row lg:px-8">
          <p className="text-xs text-slate-400">&copy; NEXON Cloud Inc. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
}
