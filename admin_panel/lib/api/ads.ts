import { createBanner, fetchBanners, removeBanner, updateBanner, type BannerItem } from "@/lib/api/banners";

export type AdItem = BannerItem;

export async function fetchAds() {
  const items = await fetchBanners();
  return items.filter((item) => Boolean(item.course_id));
}

export async function createAd(payload: {
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id: string;
  telegram: string;
}) {
  return createBanner(payload);
}

export async function updateAd(adId: string, payload: Partial<Omit<AdItem, "id">>) {
  return updateBanner(adId, payload);
}

export async function removeAd(adId: string) {
  return removeBanner(adId);
}
