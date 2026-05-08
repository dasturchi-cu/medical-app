import type { NextConfig } from "next";

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
};

export default nextConfig;
