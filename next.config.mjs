/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: {
      // Uploads in het ILT-aanvraagdossier (PDF's tot ~25 MB); default is 1 MB
      bodySizeLimit: "25mb",
    },
  },
};
export default nextConfig;
