import Link from "next/link";
import { Icon } from "@/components/ui/Icon";

interface BrandLogoProps {
  variant?: "light" | "dark"; // light = for dark backgrounds
  href?: string; // when set, the logo becomes a link
  className?: string;
}

export function BrandLogo({ variant = "dark", href, className = "" }: BrandLogoProps) {
  const isLight = variant === "light";
  const classes = `flex items-center gap-2 ${isLight ? "text-white" : "text-slate-900"} ${className}`;

  const content = (
    <>
      <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-linear-to-br from-blue-500 to-indigo-600 text-white shadow-lg shadow-blue-500/30">
        <Icon name="apartment" className="size-5" />
      </div>
      <span className="text-2xl font-bold tracking-tight">
        NEXON{" "}
        <span className={`font-light ${isLight ? "text-blue-100" : "text-slate-500"}`}>Cloud</span>
      </span>
    </>
  );

  return href ? (
    <Link href={href} className={classes}>
      {content}
    </Link>
  ) : (
    <div className={classes}>{content}</div>
  );
}
