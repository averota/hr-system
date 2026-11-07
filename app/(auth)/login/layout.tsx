// app/(auth)/login/layout.tsx
import { BrandLogo } from "@/components/ui/BrandLogo";
import { Icon } from "@/components/ui/Icon";
import { inter } from "@/lib/fonts";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  // TEMP: [--color-primary:#2563eb] keeps bg-primary blue on the auth pages only.
  // The current globals.css uses a near-black primary for the other pages.
  // Remove it once globals.css matches the reference.
  return (
    <div
      className={`${inter.className} flex min-h-dvh w-full flex-col bg-white lg:flex-row [--color-primary:#2563eb]`}
    >
      {/* Left panel: branding (desktop only) */}
      <aside className="relative hidden flex-col justify-between overflow-hidden bg-blue-900 p-12 lg:flex lg:w-1/2">
        {/* Decorative background */}
        <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden">
          <div className="absolute -left-[10%] -top-[20%] h-[70%] w-[70%] rounded-full bg-blue-600/30 blur-3xl" />
          <div className="absolute -right-[20%] bottom-[10%] h-[60%] w-[60%] rounded-full bg-indigo-500/20 blur-3xl" />
        </div>

        <BrandLogo variant="light" href="/" className="relative z-10" />

        <div className="relative z-10 mb-10 mt-20">
          <h1 className="mb-6 text-4xl font-bold leading-tight text-white lg:text-5xl">
            Empower your <br /> workforce today.
          </h1>
          <p className="max-w-md text-lg leading-relaxed text-blue-100">
            The all-in-one HRIS platform designed to streamline your human resources, payroll, and
            talent management seamlessly.
          </p>
        </div>

        {/* Testimonial */}
        <div className="relative z-10 mt-auto rounded-2xl border border-white/20 bg-white/10 p-6 backdrop-blur-[10px]">
          <div className="mb-3 flex gap-1 text-yellow-400">
            {Array.from({ length: 5 }).map((_, i) => (
              <Icon key={i} name="star" className="size-4 fill-current" />
            ))}
          </div>
          <p className="mb-4 text-sm font-medium text-white">
            &quot;NEXON Cloud transformed how we manage our global teams. It&apos;s intuitive, fast,
            and incredibly reliable.&quot;
          </p>
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full border-2 border-blue-500 bg-blue-600 font-bold text-white">
              SJ
            </div>
            <div>
              <p className="text-sm font-semibold text-white">Sarah Jenkins</p>
              <p className="text-xs text-blue-100">VP of HR, TechFlow Inc.</p>
            </div>
          </div>
        </div>
      </aside>

      {/* Right panel: page content (login form) */}
      <main className="relative flex w-full flex-col justify-center bg-white p-8 sm:p-12 lg:w-1/2 lg:p-16">
        {/* Mobile logo */}
        <BrandLogo href="/" className="mb-8 lg:hidden" />
        <div className="mx-auto w-full max-w-md">{children}</div>
      </main>
    </div>
  );
}