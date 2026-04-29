"use client";

import { useSyncExternalStore } from "react";

export type AdminLanguage = "uz" | "ru" | "en";

export interface Course {
  id: string;
  title_uz: string;
  title_ru: string;
  title_en: string;
  price: string;
  image: string;
  views: number;
  sales: number;
  has_modules: boolean;
}

export interface CourseModule {
  id: string;
  course_id: string;
  name: string;
}

export interface Lesson {
  id: string;
  courseId: string;
  module_id: string | null;
  title: string;
  videoId: string;
  order: number;
  isFree: boolean;
}

export interface Banner {
  id: string;
  title: string;
  image: string;
  courseId: string;
  message: string;
  price: string;
  telegram: string;
}

export interface User {
  id: string;
  name: string;
  email: string;
  registration_date: string;
  login_method: string;
  device_type: "Android" | "iOS";
  last_device_info: string;
  is_blocked: boolean;
  login_count: number;
  app_open_count: number;
  last_active_at: string;
}

export interface UserActivity {
  user_id: string;
  login_count: number;
  last_active_at: string;
  total_hours: number;
}

export interface VideoProgress {
  id: string;
  user_id: string;
  video_title: string;
  watched_percent: number;
  last_watched_at: string;
}

export interface PomodoroSession {
  id: string;
  user_id: string;
  focus_minutes: number;
  break_minutes: number;
  created_at: string;
}

export interface UserCourse {
  user_id: string;
  course_id: string;
  module_id: string | null;
  purchased_at: string;
  is_active: boolean;
}

export interface CommentItem {
  id: string;
  course_id: string;
  user_id: string;
  text: string;
  created_at: string;
  parent_id: string | null;
  hearts: number;
  hearted_by_admin: boolean;
}

export interface RatingItem {
  id: string;
  course_id: string;
  user_id: string;
  rating: number;
  created_at: string;
}

interface ActivityPoint {
  label: string;
  value: number;
}

interface AdminState {
  courses: Course[];
  courseModules: CourseModule[];
  lessons: Lesson[];
  banners: Banner[];
  users: User[];
  userActivityRows: UserActivity[];
  videoProgressRows: VideoProgress[];
  pomodoroSessions: PomodoroSession[];
  userCourses: UserCourse[];
  comments: CommentItem[];
  ratings: RatingItem[];
  userActivity: ActivityPoint[];
}

const fallbackImage = "";

let state: AdminState = {
  courses: [
    {
      id: "course-1",
      title_uz: "Klinik anatomiya",
      title_ru: "Клиническая анатомия",
      title_en: "Clinical Anatomy",
      price: "299 000 so'm",
      image: "",
      views: 3200,
      sales: 210,
      has_modules: true,
    },
    {
      id: "course-2",
      title_uz: "Farmakologiya asoslari",
      title_ru: "Основы фармакологии",
      title_en: "Pharmacology Basics",
      price: "349 000 so'm",
      image: "",
      views: 1900,
      sales: 124,
      has_modules: false,
    },
    {
      id: "course-3",
      title_uz: "Terapevtik amaliyot",
      title_ru: "Терапевтическая практика",
      title_en: "Therapeutic Practice",
      price: "259 000 so'm",
      image: "",
      views: 640,
      sales: 0,
      has_modules: true,
    },
  ],
  courseModules: [
    { id: "module-1-1", course_id: "course-1", name: "1-baza" },
    { id: "module-1-2", course_id: "course-1", name: "2-baza" },
    { id: "module-1-3", course_id: "course-1", name: "3-baza" },
    { id: "module-3-1", course_id: "course-3", name: "1-baza" },
    { id: "module-3-2", course_id: "course-3", name: "2-baza" },
    { id: "module-3-3", course_id: "course-3", name: "3-baza" },
  ],
  lessons: [
    { id: "lesson-1", courseId: "course-1", module_id: "module-1-1", title: "Yuqori qo'l suyaklari kirish", videoId: "ab12CdE", order: 1, isFree: true },
    { id: "lesson-2", courseId: "course-1", module_id: "module-1-2", title: "Ko'krak qafasi tuzilmalari", videoId: "Qw3Rt6Z", order: 1, isFree: false },
    { id: "lesson-3", courseId: "course-2", module_id: null, title: "Retseptor turlari", videoId: "xYz982k", order: 1, isFree: true },
  ],
  banners: [
    {
      id: "banner-1",
      title: "Bahorgi qabul boshlandi",
      image: "",
      courseId: "course-1",
      message: "Kursga yozilish ochildi. Joylar cheklangan.",
      price: "299 000 so'm",
      telegram: "med_admin",
    },
    {
      id: "banner-2",
      title: "Yangi farmakologiya kursi",
      image: "",
      courseId: "course-2",
      message: "Yangi oqim uchun maxsus narx.",
      price: "349 000 so'm",
      telegram: "med_admin",
    },
  ],
  users: [
    {
      id: "user-1",
      name: "Ali Karimov",
      email: "ali.karimov@gmail.com",
      registration_date: "2025-11-14",
      login_method: "Email/Parol",
      device_type: "Android",
      last_device_info: "Samsung Galaxy A54 / Android 14",
      is_blocked: false,
      login_count: 54,
      app_open_count: 209,
      last_active_at: "2026-04-29 14:20",
    },
    {
      id: "user-2",
      name: "Madina Sobirova",
      email: "madina.sobirova@gmail.com",
      registration_date: "2026-01-03",
      login_method: "Telegram ID",
      device_type: "iOS",
      last_device_info: "iPhone 13 / iOS 18.1",
      is_blocked: false,
      login_count: 27,
      app_open_count: 96,
      last_active_at: "2026-04-29 11:05",
    },
  ],
  userActivityRows: [
    { user_id: "user-1", login_count: 54, last_active_at: "2026-04-29 14:20", total_hours: 132 },
    { user_id: "user-2", login_count: 27, last_active_at: "2026-04-29 11:05", total_hours: 66 },
  ],
  videoProgressRows: [
    { id: "vp-1", user_id: "user-1", video_title: "Yuqori qo'l suyaklari kirish", watched_percent: 100, last_watched_at: "2026-04-29 13:10" },
    { id: "vp-2", user_id: "user-1", video_title: "Ko'krak qafasi tuzilmalari", watched_percent: 72, last_watched_at: "2026-04-29 13:54" },
    { id: "vp-3", user_id: "user-2", video_title: "Retseptor turlari", watched_percent: 45, last_watched_at: "2026-04-28 21:12" },
  ],
  pomodoroSessions: [
    { id: "pomo-1", user_id: "user-1", focus_minutes: 50, break_minutes: 10, created_at: "2026-04-29 09:10" },
    { id: "pomo-2", user_id: "user-1", focus_minutes: 75, break_minutes: 15, created_at: "2026-04-29 11:30" },
    { id: "pomo-3", user_id: "user-2", focus_minutes: 40, break_minutes: 10, created_at: "2026-04-28 20:00" },
  ],
  userCourses: [
    { user_id: "user-1", course_id: "course-1", module_id: "module-1-2", purchased_at: "2026-02-02", is_active: true },
    { user_id: "user-1", course_id: "course-2", module_id: null, purchased_at: "2026-03-14", is_active: true },
    { user_id: "user-1", course_id: "course-3", module_id: null, purchased_at: "", is_active: false },
    { user_id: "user-2", course_id: "course-1", module_id: "module-1-1", purchased_at: "2026-04-01", is_active: true },
    { user_id: "user-2", course_id: "course-2", module_id: null, purchased_at: "", is_active: false },
    { user_id: "user-2", course_id: "course-3", module_id: null, purchased_at: "", is_active: false },
  ],
  comments: [
    {
      id: "comment-1",
      course_id: "course-1",
      user_id: "user-1",
      text: "Kurs juda tushunarli va amaliy bo'ldi.",
      created_at: "2026-04-20",
      parent_id: null,
      hearts: 5,
      hearted_by_admin: false,
    },
    {
      id: "comment-2",
      course_id: "course-2",
      user_id: "user-2",
      text: "Yaxshi, ammo yana ko'proq misollar kerak.",
      created_at: "2026-04-22",
      parent_id: null,
      hearts: 3,
      hearted_by_admin: false,
    },
    {
      id: "comment-3",
      course_id: "course-1",
      user_id: "user-2",
      text: "Rahmat, bu mavzuning keyingi qismi ham bo'ladimi?",
      created_at: "2026-04-22",
      parent_id: "comment-1",
      hearts: 1,
      hearted_by_admin: false,
    },
  ],
  ratings: [
    { id: "rate-1", course_id: "course-1", user_id: "user-1", rating: 5, created_at: "2026-04-20" },
    { id: "rate-2", course_id: "course-2", user_id: "user-2", rating: 4, created_at: "2026-04-22" },
  ],
  userActivity: [
    { label: "Du", value: 24 },
    { label: "Se", value: 33 },
    { label: "Ch", value: 30 },
    { label: "Pa", value: 41 },
    { label: "Ju", value: 38 },
    { label: "Sh", value: 18 },
    { label: "Ya", value: 22 },
  ],
};

type Listener = () => void;
const listeners = new Set<Listener>();

function notify() {
  listeners.forEach((listener) => listener());
}

function updateState(updater: (current: AdminState) => AdminState) {
  state = updater(state);
  notify();
}

export function useAdminStore<T>(selector: (current: AdminState) => T): T {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => selector(state),
    () => selector(state),
  );
}

export const adminActions = {
  addCourse(course: { title: string; image: string; price: string; has_modules: boolean; modules: string[] }) {
    const translated = autoTranslateTitle(course.title);
    const courseId = `course-${Date.now()}`;
    const generatedModules = course.has_modules
      ? course.modules
          .map((name) => name.trim())
          .filter(Boolean)
          .map((name, index) => ({
            id: `module-${courseId}-${index + 1}`,
            course_id: courseId,
            name,
          }))
      : [];

    updateState((current) => ({
      ...current,
      courses: [
        {
          id: courseId,
          image: course.image,
          price: course.price.trim() || "Kelishiladi",
          views: 0,
          sales: 0,
          has_modules: course.has_modules,
          ...translated,
        },
        ...current.courses,
      ],
      courseModules: [...generatedModules, ...current.courseModules],
    }));
  },
  updateCourse(
    id: string,
    payload: { title: string; image: string; price: string; has_modules: boolean; modules: string[] },
  ) {
    const translated = autoTranslateTitle(payload.title);
    const nextModules = payload.has_modules
      ? payload.modules
          .map((name) => name.trim())
          .filter(Boolean)
          .map((name, index) => ({
            id: `module-${id}-${index + 1}`,
            course_id: id,
            name,
          }))
      : [];

    updateState((current) => ({
      ...current,
      courses: current.courses.map((course) =>
        course.id === id
          ? {
              ...course,
              image: payload.image,
              price: payload.price.trim() || "Kelishiladi",
              has_modules: payload.has_modules,
              ...translated,
            }
          : course,
      ),
      courseModules: [
        ...current.courseModules.filter((module) => module.course_id !== id),
        ...nextModules,
      ],
      lessons: current.lessons.map((lesson) =>
        lesson.courseId === id && !payload.has_modules
          ? { ...lesson, module_id: null }
          : lesson,
      ),
      userCourses: current.userCourses.map((access) =>
        access.course_id === id && !payload.has_modules
          ? { ...access, module_id: null }
          : access,
      ),
    }));
  },
  deleteCourse(id: string) {
    updateState((current) => ({
      ...current,
      courses: current.courses.filter((course) => course.id !== id),
      lessons: current.lessons.filter((lesson) => lesson.courseId !== id),
      courseModules: current.courseModules.filter((module) => module.course_id !== id),
      banners: current.banners.filter((banner) => banner.courseId !== id),
      userCourses: current.userCourses.filter((relation) => relation.course_id !== id),
      comments: current.comments.filter((comment) => comment.course_id !== id),
      ratings: current.ratings.filter((rating) => rating.course_id !== id),
    }));
  },
  addLesson(lesson: Omit<Lesson, "id">) {
    updateState((current) => ({
      ...current,
      lessons: [{ ...lesson, id: `lesson-${Date.now()}` }, ...current.lessons],
    }));
  },
  updateLesson(id: string, payload: Omit<Lesson, "id">) {
    updateState((current) => ({
      ...current,
      lessons: current.lessons.map((lesson) => (lesson.id === id ? { ...lesson, ...payload } : lesson)),
    }));
  },
  deleteLesson(id: string) {
    updateState((current) => ({
      ...current,
      lessons: current.lessons.filter((lesson) => lesson.id !== id),
    }));
  },
  addBanner(banner: Omit<Banner, "id">) {
    updateState((current) => ({
      ...current,
      banners: [{ ...banner, id: `banner-${Date.now()}` }, ...current.banners],
    }));
  },
  updateBanner(id: string, payload: Omit<Banner, "id">) {
    updateState((current) => ({
      ...current,
      banners: current.banners.map((banner) => (banner.id === id ? { ...banner, ...payload } : banner)),
    }));
  },
  deleteBanner(id: string) {
    updateState((current) => ({
      ...current,
      banners: current.banners.filter((banner) => banner.id !== id),
    }));
  },
  grantCourse(userId: string, courseId: string, moduleId: string | null) {
    updateState((current) => ({
      ...current,
      userCourses: current.userCourses.some(
        (relation) =>
          relation.user_id === userId &&
          relation.course_id === courseId &&
          relation.module_id === moduleId,
      )
        ? current.userCourses.map((relation) =>
            relation.user_id === userId &&
            relation.course_id === courseId &&
            relation.module_id === moduleId
              ? { ...relation, is_active: true }
              : relation,
          )
        : [
            ...current.userCourses,
            {
              user_id: userId,
              course_id: courseId,
              module_id: moduleId,
              purchased_at: "",
              is_active: true,
            },
          ],
    }));
  },
  blockUser(userId: string) {
    updateState((current) => ({
      ...current,
      users: current.users.map((user) => (user.id === userId ? { ...user, is_blocked: true } : user)),
    }));
  },
  unblockUser(userId: string) {
    updateState((current) => ({
      ...current,
      users: current.users.map((user) => (user.id === userId ? { ...user, is_blocked: false } : user)),
    }));
  },
  revokeCourse(userId: string, courseId: string, moduleId: string | null = null) {
    updateState((current) => ({
      ...current,
      userCourses: current.userCourses.map((relation) =>
        relation.user_id === userId &&
        relation.course_id === courseId &&
        relation.module_id === moduleId
          ? { ...relation, is_active: false }
          : relation,
      ),
    }));
  },
  deleteComment(commentId: string) {
    updateState((current) => ({
      ...current,
      comments: current.comments.filter(
        (comment) => comment.id !== commentId && comment.parent_id !== commentId,
      ),
    }));
  },
  addCommentReply(payload: { parentId: string; courseId: string; text: string }) {
    const nextText = payload.text.trim();
    if (!nextText) return;
    updateState((current) => ({
      ...current,
      comments: [
        ...current.comments,
        {
          id: `comment-${Date.now()}`,
          course_id: payload.courseId,
          user_id: "admin",
          text: nextText,
          created_at: new Date().toISOString().slice(0, 10),
          parent_id: payload.parentId,
          hearts: 0,
          hearted_by_admin: false,
        },
      ],
    }));
  },
  toggleCommentHeart(commentId: string) {
    updateState((current) => ({
      ...current,
      comments: current.comments.map((comment) => {
        if (comment.id !== commentId) return comment;
        const nextHearted = !comment.hearted_by_admin;
        return {
          ...comment,
          hearted_by_admin: nextHearted,
          hearts: Math.max(0, comment.hearts + (nextHearted ? 1 : -1)),
        };
      }),
    }));
  },
  reorderLesson(courseId: string, lessonId: string, direction: "up" | "down") {
    updateState((current) => {
      const sameCourse = [...current.lessons]
        .filter((lesson) => lesson.courseId === courseId)
        .sort((a, b) => a.order - b.order);
      const index = sameCourse.findIndex((lesson) => lesson.id === lessonId);
      if (index === -1) return current;

      const swapIndex = direction === "up" ? index - 1 : index + 1;
      if (swapIndex < 0 || swapIndex >= sameCourse.length) return current;

      const currentLesson = sameCourse[index];
      const swapLesson = sameCourse[swapIndex];

      return {
        ...current,
        lessons: current.lessons.map((lesson) => {
          if (lesson.id === currentLesson.id) return { ...lesson, order: swapLesson.order };
          if (lesson.id === swapLesson.id) return { ...lesson, order: currentLesson.order };
          return lesson;
        }),
      };
    });
  },
};

export function courseTitleByLanguage(course: Course, language: AdminLanguage) {
  if (language === "uz") return course.title_uz;
  if (language === "ru") return course.title_ru;
  return course.title_en;
}

export function resolveImage(src: string) {
  return src.trim() || fallbackImage;
}

export function canUserLogin(userId: string) {
  const user = state.users.find((entry) => entry.id === userId);
  return Boolean(user && !user.is_blocked);
}

export function getCourseModules(courseId: string) {
  return state.courseModules.filter((module) => module.course_id === courseId);
}

export function getUserAccessibleLessons(userId: string, courseId: string) {
  const access = state.userCourses.find(
    (item) => item.user_id === userId && item.course_id === courseId && item.is_active,
  );
  if (!access) return [];

  const lessons = state.lessons.filter((lesson) => lesson.courseId === courseId);
  if (!access.module_id) return lessons;
  return lessons.filter((lesson) => lesson.module_id === access.module_id);
}

function autoTranslateTitle(title: string) {
  const trimmed = title.trim();
  return {
    title_uz: trimmed,
    title_ru: `${trimmed} (RU)`,
    title_en: `${trimmed} (EN)`,
  };
}
