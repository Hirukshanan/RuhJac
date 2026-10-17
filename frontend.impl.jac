"""Client handlers for planner interactions."""

impl app.load_workspace -> None {
    loading = True;
    try {
        tasks = await list_tasks();
        courses = await list_courses();
    } except Exception {
        notice = "We couldn’t load your planner. Please refresh and try again.";
    }
    loading = False;
}

impl app.handle_auth(e: FormEvent) -> None {
    e.preventDefault();
    account_error = "";
    if len(email.strip()) < 3 or len(password) < 8 {
        account_error = "Enter a valid email and a password with at least 8 characters.";
        return;
    }
    loading = True;
    try {
        if signup_mode {
            result: dict | None = None;
            result = await jacSignup([{"type": "username", "value": email.strip()}, {"type": "email", "value": email.strip()}], password);
            if not result["success"] {
                account_error = result.get("error", "We couldn’t create your account. Try signing in if you already registered.") as str;
                loading = False;
                return;
            }
            signed_in: bool = False;
            signed_in = await jacLogin(email.strip(), password);
            if not signed_in {
                account_error = "Your account was created. Please sign in to continue.";
                signup_mode = False;
                loading = False;
                return;
            }
        } else {
            signed_in: bool = False;
            signed_in = await jacLogin(email.strip(), password);
            if not signed_in {
                account_error = "That email and password didn’t match. Please try again.";
                loading = False;
                return;
            }
        }
        logged_in = True;
        await load_workspace();
    } except Exception {
        account_error = "We couldn’t reach the sign-in service. Please try again.";
    }
    loading = False;
}

impl app.sign_out(e: MouseEvent) -> None {
    try { _ = await disconnect_moodle(); } except Exception {}
    jacLogout();
    logged_in = False;
    tasks = [];
    courses = [];
    email = "";
    password = "";
    active_view = "Today";
}

impl app.set_view(name: str) -> None {
    active_view = name;
    task_course = "";
}

impl app.open_new_task(e: MouseEvent) -> None {
    selected_task = None;
    task_title = "";
    task_description = "";
    task_course = "";
    task_due = "";
    task_priority = "Medium";
    task_estimate = "60";
    task_tags = "";
    task_error = "";
    show_task_form = True;
}

impl app.edit_task(item: Task) -> None {
    selected_task = item;
    task_title = item.title;
    task_description = item.description;
    task_course = item.course;
    task_due = item.due;
    task_priority = item.priority;
    task_estimate = str(item.estimate);
    task_tags = item.tags;
    task_error = "";
    show_task_form = True;
}

impl app.save_task(e: FormEvent) -> None {
    e.preventDefault();
    task_error = "";
    if len(task_title.strip()) < 2 {
        task_error = "Add a short title so you can find this task later.";
        return;
    }
    minutes: int = 60;
    try { minutes = int(task_estimate); } except ValueError { minutes = 60; }
    if minutes < 5 or minutes > 600 {
        task_error = "Estimated effort must be between 5 and 600 minutes.";
        return;
    }
    try {
        if selected_task is not None {
            saved = await update_task(jid(selected_task), task_title.strip(), task_description.strip(), task_course, task_due, task_priority, minutes, task_tags.strip(), selected_task.completed);
            if saved is None { task_error = "This task is no longer available. Refresh and try again."; return; }
            notice = "Task updated.";
        } else {
            saved = await add_task(task_title.strip(), task_description.strip(), task_course, task_due, task_priority, minutes, task_tags.strip());
            notice = "Task added to your planner.";
        }
        show_task_form = False;
        selected_task = None;
        await load_workspace();
    } except Exception {
        task_error = "We couldn’t save that task. Please try again.";
    }
}

impl app.toggle_task(item: Task) -> None {
    try {
        _ = await update_task(jid(item), item.title, item.description, item.course, item.due, item.priority, item.estimate, item.tags, not item.completed);
        selected_task = None;
        notice = "Task completed. Nice work." if not item.completed else "Task reopened.";
        await load_workspace();
    } except Exception { notice = "We couldn’t update that task. Try again."; }
}

impl app.remove_task(item: Task) -> None {
    try {
        _ = await delete_task(jid(item));
        deleted_task = item;
        selected_task = None;
        show_task_form = False;
        notice = "Task removed from your planner.";
        await load_workspace();
    } except Exception { task_error = "We couldn’t remove that task. Try again."; }
}

impl app.restore_deleted(e: MouseEvent) -> None {
    if deleted_task is not None {
        try {
            restored = await restore_task(jid(deleted_task));
            if restored is not None {
                notice = "Task restored to your planner.";
                deleted_task = None;
                await load_workspace();
            }
        } except Exception { notice = "We couldn’t restore that task. Please refresh and try again."; }
    }
}

impl app.remove_selected(e: MouseEvent) -> None {
    if selected_task is not None { await remove_task(selected_task); }
}

impl app.toggle_selected(e: MouseEvent) -> None {
    if selected_task is not None { await toggle_task(selected_task); }
}

impl app.edit_selected(e: MouseEvent) -> None {
    if selected_task is not None { edit_task(selected_task); }
}

impl app.capture_task(e: FormEvent) -> None {
    e.preventDefault();
    if len(quick_text.strip()) < 2 { return; }
    try {
        proposed: TaskDraft = await propose_task(quick_text.strip());
        draft = proposed;
        task_title = proposed.title;
        task_description = proposed.description;
        task_course = proposed.course;
        task_due = proposed.due;
        task_priority = proposed.priority;
        task_estimate = str(proposed.estimate);
        task_tags = proposed.tags;
        selected_task = None;
        task_error = "Review the suggested details, then save when they look right.";
        show_task_form = True;
        quick_text = "";
    } except Exception {
        task_title = quick_text.strip();
        task_description = "";
        task_course = "";
        task_due = "";
        task_priority = "Medium";
        task_estimate = "60";
        task_tags = "";
        selected_task = None;
        task_error = "Couldn’t parse that yet. Review the task details and save them manually.";
        show_task_form = True;
    }
}

impl app.ask_assistant(e: FormEvent) -> None {
    e.preventDefault();
    assistant_error = "";
    assistant_loading = True;
    context: str = "";
    for item in tasks[:20] {
        if not item.deleted {
            context += f"Task: {item.title}; course: {item.course}; due: {item.due}; estimated minutes: {item.estimate}; status: { 'completed' if item.completed else 'open' }. ";
        }
    }
    try {
        assistant_reply = await study_assist(assistant_prompt.strip(), context);
    } except Exception {
        assistant_error = "The study assistant is unavailable right now. You can keep planning manually; check the Gemini setup if this continues.";
    }
    assistant_loading = False;
}

impl app.plan_day(e: MouseEvent) -> None {
    active_view = "Assistant";
    assistant_prompt = f"Plan my study session for the next {assistant_minutes} minutes. Use time blocks, short breaks, and prioritize tasks with earlier due dates and higher effort. Do not assume more available time than I gave you.";
    assistant_error = "";
    assistant_loading = True;
    context: str = "";
    for item in tasks[:20] {
        if not item.completed and not item.deleted {
            context += f"Task: {item.title}; course: {item.course}; due: {item.due}; estimated minutes: {item.estimate}; priority: {item.priority}. ";
        }
    }
    try {
        assistant_reply = await study_assist(assistant_prompt, context);
    } except Exception {
        assistant_error = "The study assistant is unavailable right now. You can keep planning manually; check the Gemini setup if this continues.";
    }
    assistant_loading = False;
}

impl app.save_draft(item: TaskDraft) -> None {
    task_title = item.title;
    task_description = item.description;
    task_course = item.course;
    task_due = item.due;
    task_priority = item.priority;
    task_estimate = str(item.estimate);
    task_tags = item.tags;
    selected_task = None;
    task_error = "Review this suggestion before saving.";
    show_task_form = True;
}

impl app.create_course(e: FormEvent) -> None {
    e.preventDefault();
    if len(course_name.strip()) < 2 { return; }
    try {
        _ = await add_course(course_name.strip(), course_code.strip(), "#6571de");
        course_name = "";
        course_code = "";
        show_course_form = False;
        notice = "Course added.";
        await load_workspace();
    } except Exception { notice = "We couldn’t add that course. Please try again."; }
}
