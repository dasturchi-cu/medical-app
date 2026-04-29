"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { PageSkeleton } from "@/components/page-skeleton";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  createTest,
  createTestQuestion,
  deleteTest,
  fetchTestQuestions,
  fetchTests,
  type TestItem,
  type TestQuestionItem,
} from "@/lib/api/tests";
import { fetchCourses, type CourseItem } from "@/lib/api/courses";
import { fetchLessons, type LessonItem } from "@/lib/api/lessons";
import { notifyError, notifySuccess } from "@/lib/notify";

export default function TestsPage() {
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [tests, setTests] = useState<TestItem[]>([]);
  const [selectedTestId, setSelectedTestId] = useState<string>("");
  const [questions, setQuestions] = useState<TestQuestionItem[]>([]);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [testValues, setTestValues] = useState({
    title: "",
    description: "",
    estimated_minutes: "10",
    course_id: "",
    lesson_id: "",
  });
  const [qValues, setQValues] = useState({
    question_text: "",
    option_a: "",
    option_b: "",
    option_c: "",
    option_d: "",
    correct_option: "A" as "A" | "B" | "C" | "D",
  });

  useEffect(() => {
    let mounted = true;
    void Promise.all([fetchTests(), fetchCourses(), fetchLessons()])
      .then(([testsItems, courseItems, lessonItems]) => {
        if (!mounted) return;
        setTests(testsItems);
        setSelectedTestId(testsItems[0]?.id ?? "");
        setCourses(courseItems);
        setLessons(lessonItems);
      })
      .catch((error) => {
        if (mounted) notifyError(error instanceof Error ? error.message : "Test ma'lumotlarini olishda xatolik.");
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (!selectedTestId) return;
    void fetchTestQuestions(selectedTestId)
      .then(setQuestions)
      .catch((error) => {
        notifyError(error instanceof Error ? error.message : "Savollarni olishda xatolik.");
        setQuestions([]);
      });
  }, [selectedTestId]);

  const visibleQuestions = selectedTestId ? questions : [];

  const testColumns = useMemo(
    () => [
      { key: "title", label: "Test nomi" },
      {
        key: "lesson_id",
        label: "Dars",
        render: (item: TestItem) => lessons.find((lesson) => lesson.id === item.lesson_id)?.title ?? "Tanlanmagan",
      },
      { key: "estimated_minutes", label: "Daqiqa" },
      { key: "question_count", label: "Savollar" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: TestItem) => (
          <div className="flex gap-2">
            <Button className="h-8 rounded-lg px-3 text-xs" variant="outline" onClick={() => setSelectedTestId(item.id)}>
              Tanlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [lessons],
  );

  const questionColumns = useMemo(
    () => [
      { key: "order_no", label: "#" },
      { key: "question_text", label: "Savol" },
      { key: "correct_option", label: "To'g'ri" },
    ],
    [],
  );

  const onCreateTest = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!testValues.lesson_id) {
      notifyError("Test userga chiqishi uchun dars tanlash majburiy.");
      return;
    }
    void createTest({
      title: testValues.title,
      description: testValues.description,
      estimated_minutes: Number(testValues.estimated_minutes) || 10,
      course_id: testValues.course_id || null,
      lesson_id: testValues.lesson_id || null,
    })
      .then((item) => {
        setTests((prev) => [item, ...prev]);
        setSelectedTestId(item.id);
        setTestValues({ title: "", description: "", estimated_minutes: "10", course_id: "", lesson_id: "" });
        notifySuccess("Test yaratildi.");
      })
      .catch((error) => {
        notifyError(error instanceof Error ? error.message : "Test yaratilmadi.");
      });
  };

  const filteredLessons = lessons.filter((item) => {
    if (!testValues.course_id) return true;
    return item.course_id === testValues.course_id;
  });

  const onCreateQuestion = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!selectedTestId) {
      notifyError("Avval test tanlang.");
      return;
    }
    void createTestQuestion(selectedTestId, {
      question_text: qValues.question_text,
      option_a: qValues.option_a,
      option_b: qValues.option_b,
      option_c: qValues.option_c,
      option_d: qValues.option_d,
      correct_option: qValues.correct_option,
      order_no: questions.length + 1,
    })
      .then((item) => {
        setQuestions((prev) => [...prev, item].sort((a, b) => a.order_no - b.order_no));
        setTests((prev) => prev.map((t) => (t.id === selectedTestId ? { ...t, question_count: t.question_count + 1 } : t)));
        setQValues({
          question_text: "",
          option_a: "",
          option_b: "",
          option_c: "",
          option_d: "",
          correct_option: "A",
        });
        notifySuccess("Savol qo'shildi.");
      })
      .catch((error) => {
        notifyError(error instanceof Error ? error.message : "Savol qo'shilmadi.");
      });
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm title="Yangi test yaratish" description="Kursga bog'langan testlar shu yerdan boshqariladi." onSubmit={onCreateTest}>
        <div className="grid gap-2">
          <Label htmlFor="testTitle">Test nomi</Label>
          <Input id="testTitle" value={testValues.title} onChange={(e) => setTestValues((p) => ({ ...p, title: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="testDesc">Izoh</Label>
          <Input
            id="testDesc"
            value={testValues.description}
            onChange={(e) => setTestValues((p) => ({ ...p, description: e.target.value }))}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="testMin">Taxminiy daqiqa</Label>
          <Input
            id="testMin"
            value={testValues.estimated_minutes}
            onChange={(e) => setTestValues((p) => ({ ...p, estimated_minutes: e.target.value }))}
          />
        </div>
        <div className="grid gap-2">
          <div className="grid gap-2">
            <Label htmlFor="courseSelect">Kurs tanlash</Label>
            <select
              id="courseSelect"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={testValues.course_id}
              onChange={(e) => {
                const courseId = e.target.value;
                setTestValues((p) => ({ ...p, course_id: courseId, lesson_id: "" }));
              }}
            >
              <option value="">Kurs tanlanmagan</option>
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.title_uz}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lessonSelect">Dars tanlash</Label>
            <select
              id="lessonSelect"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={testValues.lesson_id}
              onChange={(e) => setTestValues((p) => ({ ...p, lesson_id: e.target.value }))}
            >
              <option value="">Dars tanlanmagan</option>
              {filteredLessons.map((lesson) => (
                <option key={lesson.id} value={lesson.id}>
                  {lesson.title}
                </option>
              ))}
            </select>
          </div>
        </div>
      </AppForm>

      <AppTable columns={testColumns} data={tests} emptyText="Hali test yo'q." />

      <AppForm
        title="Savol qo'shish"
        description={selectedTestId ? "Tanlangan testga savol qo'shiladi." : "Avval test tanlang."}
        onSubmit={onCreateQuestion}
        submitLabel="Savol qo'shish"
      >
        <div className="grid gap-2">
          <Label htmlFor="selectedTest">Tanlangan test</Label>
          <select
            id="selectedTest"
            className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
            value={selectedTestId}
            onChange={(e) => setSelectedTestId(e.target.value)}
          >
            <option value="">Test tanlanmagan</option>
            {tests.map((test) => (
              <option key={test.id} value={test.id}>
                {test.title}
              </option>
            ))}
          </select>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="questionText">Savol matni</Label>
          <Input id="questionText" value={qValues.question_text} onChange={(e) => setQValues((p) => ({ ...p, question_text: e.target.value }))} />
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <Input placeholder="A variant" value={qValues.option_a} onChange={(e) => setQValues((p) => ({ ...p, option_a: e.target.value }))} />
          <Input placeholder="B variant" value={qValues.option_b} onChange={(e) => setQValues((p) => ({ ...p, option_b: e.target.value }))} />
          <Input placeholder="C variant" value={qValues.option_c} onChange={(e) => setQValues((p) => ({ ...p, option_c: e.target.value }))} />
          <Input placeholder="D variant" value={qValues.option_d} onChange={(e) => setQValues((p) => ({ ...p, option_d: e.target.value }))} />
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <select
            className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
            value={qValues.correct_option}
            onChange={(e) => setQValues((p) => ({ ...p, correct_option: e.target.value as "A" | "B" | "C" | "D" }))}
          >
            <option value="A">To&apos;g&apos;ri javob: A</option>
            <option value="B">To&apos;g&apos;ri javob: B</option>
            <option value="C">To&apos;g&apos;ri javob: C</option>
            <option value="D">To&apos;g&apos;ri javob: D</option>
          </select>
        </div>
      </AppForm>

      <AppTable columns={questionColumns} data={visibleQuestions} emptyText="Bu testda savol yo&apos;q." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Testni o'chirish"
        description="Test va unga tegishli barcha savollar o'chadi."
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          if (!deleteId) return;
          void deleteTest(deleteId).then(() => {
            setTests((prev) => prev.filter((item) => item.id !== deleteId));
            if (selectedTestId === deleteId) {
              setSelectedTestId("");
              setQuestions([]);
            }
            setDeleteId(null);
            notifySuccess("Test o'chirildi.");
          }).catch((error) => {
            notifyError(error instanceof Error ? error.message : "Test o'chirilmadi.");
          });
        }}
      />
    </section>
  );
}
