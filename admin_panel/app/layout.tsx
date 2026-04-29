import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Ta'lim Platformasi Admini",
  description: "Kurslar, darslar va bannerlarni boshqarish uchun admin panel.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="uz" className="h-full antialiased">
      <body className="min-h-full bg-[#f7f9fc] text-slate-900">{children}</body>
    </html>
  );
}
