import type { NextConfig } from "next";

const backendOrigin = (process.env.NEXT_PUBLIC_API_BASE_URL ?? "").replace(/\/+$/, "");

const nextConfig: NextConfig = {
  allowedDevOrigins: ["192.168.100.168"],
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "jcwvunjccbrmqtodsodm.supabase.co",
      },
    ],
  },
  async rewrites() {
    if (!backendOrigin.startsWith("http")) return [];
    return [
      {
        source: "/api/backend-proxy/:path*",
        destination: `${backendOrigin}/:path*`,
      },
    ];
  },
};

export default nextConfig;
