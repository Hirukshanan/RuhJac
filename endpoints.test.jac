test "task lifecycle persists and can be recovered before deletion" {
    course = add_course("RuhJac QA Biology", "QA-BIO", "#6571de");
    task = add_task("Review cell notes", "Read the first section", course.name, "2026-10-21T12:00", "High", 45, "reading");
    listed = list_tasks();
    assert len([item for item in listed if jid(item) == jid(task)]) == 1;

    updated = update_task(jid(task), task.title, task.description, task.course, task.due, task.priority, task.estimate, task.tags, True);
    assert updated is not None;
    assert updated.completed;

    reopened = update_task(jid(task), task.title, task.description, task.course, task.due, task.priority, task.estimate, task.tags, False);
    assert reopened is not None;
    assert not reopened.completed;

    assert delete_task(jid(task));
    assert len([item for item in list_tasks() if jid(item) == jid(task)]) == 0;
    restored = restore_task(jid(task));
    assert restored is not None;
    assert len([item for item in list_tasks() if jid(item) == jid(task)]) == 1;
    assert delete_task(jid(task));
    remaining = list_tasks();
    assert len([item for item in remaining if jid(item) == jid(task)]) == 0;
}

test "quick capture validates empty input before calling Gemini" {
    try {
        _ = propose_task("  ");
        assert False, "empty quick capture should be rejected";
    } except ValueError {
        assert True;
    }
}

test "structured task values are bounded and normalized on the server" {
    draft = _validate_task_draft(TaskDraft(title="  Review notes  ", due="not-a-date", priority="urgent", estimate=900, tags="x" * 260));
    assert draft.title == "Review notes";
    assert draft.due == "";
    assert draft.priority == "Medium";
    assert draft.estimate == 600;
    assert len(draft.tags) == 240;
}
