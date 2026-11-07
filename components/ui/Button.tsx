import React, { ButtonHTMLAttributes } from 'react';
import Link from 'next/link';
import { Icon } from '@/components/ui/Icon';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'outline' | 'ghost' | 'icon';
  size?: 'sm' | 'md' | 'lg' | 'icon';
  icon?: string; // Icon name registered in Icon.tsx (e.g., 'arrow_back')
  iconPosition?: 'left' | 'right';
  href?: string; // When set, renders a link styled as a button (other button props are ignored)
  children?: React.ReactNode;
}

export function Button({
  variant = 'primary',
  size = 'md',
  icon,
  iconPosition = 'left',
  href,
  className = '',
  children,
  ...props
}: ButtonProps) {

  // Base classes applied to all buttons (includes the shared disabled state)
  const baseClasses = "inline-flex items-center justify-center gap-1.5 font-bold rounded-lg transition-colors focus:outline-none disabled:cursor-not-allowed disabled:opacity-60";

  // Variant-specific styles
  const variants = {
    primary: "bg-primary text-white shadow-sm hover:bg-primary-700 border border-transparent",
    outline: "border border-border-light text-slate-600 hover:bg-slate-100 hover:text-primary",
    ghost: "border border-transparent text-slate-600 hover:bg-slate-100 hover:border-border-light",
    icon: "text-slate-500 hover:text-primary hover:bg-slate-100" // For icon-only buttons
  };

  // Size-specific styles
  const sizes = {
    sm: "px-2.5 py-1 text-xs",
    md: "px-3.5 py-2 text-xs",
    lg: "px-5 py-2.5 text-xs rounded-xl", // The modal primary button uses rounded-xl
    icon: "p-2" // Used for header/sidebar toggle icons
  };

  // Combine classes based on props
  const buttonClasses = `${baseClasses} ${variants[variant]} ${sizes[size]} ${className}`;

  const content = (
    <>
      {icon && iconPosition === 'left' && <Icon name={icon} className="size-4" />}

      {/* Only render children if they exist (allows for icon-only buttons) */}
      {children && <span>{children}</span>}

      {icon && iconPosition === 'right' && <Icon name={icon} className="size-3.5" />}
    </>
  );

  if (href) {
    return (
      <Link href={href} className={buttonClasses}>
        {content}
      </Link>
    );
  }

  return (
    <button className={buttonClasses} {...props}>
      {content}
    </button>
  );
}
