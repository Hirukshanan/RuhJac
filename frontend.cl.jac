"""RuhJac planner interface."""

import "./styles/global.css";
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
import from .lms_panel { MoodlePanel }
sv import from endpoints { Task, Course, TaskDraft, StudyReply, list_tasks, list_courses, add_task, update_task, delete_task, restore_task, add_course, propose_task, study_assist }
sv import from moodle { disconnect_moodle }

def local_today() -> str {
    now = new(Date);
    month = ("0" + str(now.getMonth() + 1))[-2:];
    day = ("0" + str(now.getDate()))[-2:];
    return str(now.getFullYear()) + "-" + month + "-" + day;
}

def:pub app -> JsxElement {
    has logged_in: bool = jacIsLoggedIn(),
        signup_mode: bool = False,
        email: str = "",
        password: str = "",
        account_error: str = "",
        loading: bool = False,
        tasks: list[Task] = [],
        courses: list[Course] = [],
        active_view: str = "Today",
        selected_task: Task | None = None,
        deleted_task: Task | None = None,
        query: str = "",
        task_title: str = "",
        task_description: str = "",
        task_course: str = "",
        task_due: str = "",
        task_priority: str = "Medium",
        task_estimate: str = "60",
        task_tags: str = "",
        task_error: str = "",
        show_task_form: bool = False,
        quick_text: str = "",
        draft: TaskDraft | None = None,
        assistant_prompt: str = "",
        assistant_reply: StudyReply | None = None,
        assistant_error: str = "",
        assistant_loading: bool = False,
        assistant_minutes: str = "180",
        course_name: str = "",
        course_code: str = "",
        show_course_form: bool = False,
        notice: str = "";

    async can with entry {
        if logged_in { load_workspace(); }
    }

    async def load_workspace() -> None;
    async def handle_auth(e: FormEvent) -> None;
    async def sign_out(e: MouseEvent) -> None;
    def set_view(name: str) -> None;
    def open_new_task(e: MouseEvent) -> None;
    def edit_task(item: Task) -> None;
    async def save_task(e: FormEvent) -> None;
    async def remove_task(item: Task) -> None;
    async def restore_deleted(e: MouseEvent) -> None;
    async def toggle_task(item: Task) -> None;
    async def remove_selected(e: MouseEvent) -> None;
    async def toggle_selected(e: MouseEvent) -> None;
    def edit_selected(e: MouseEvent) -> None;
    async def capture_task(e: FormEvent) -> None;
    async def ask_assistant(e: FormEvent) -> None;
    async def plan_day(e: MouseEvent) -> None;
    async def save_draft(item: TaskDraft) -> None;
    async def create_course(e: FormEvent) -> None;

    if not logged_in {
        return <main className="auth-shell">
            <section className="auth-aside">
                <a className="brand brand-light" href="#"><span className="brand-mark">r</span> ruhjac</a>
                <div className="auth-message"><span className="eyebrow">YOUR SEMESTER, IN SYNC</span><h1>Make room for the work that matters.</h1><p>One calm place to capture coursework, see what’s next, and turn big assignments into a plan.</p></div>
                <div className="auth-foot">A little more clarity, every study day.</div>
            </section>
            <section className="auth-main"><div className="auth-card">
                <a className="brand brand-mobile" href="#"><span className="brand-mark">r</span> ruhjac</a>
                <span className="eyebrow">{"WELCOME BACK" if not signup_mode else "A FRESH START"}</span>
                <h2>{"Sign in to your planner" if not signup_mode else "Create your account"}</h2>
                <p className="muted">{ "Pick up where you left off." if not signup_mode else "Your planner is ready when you are." }</p>
                <form onSubmit={handle_auth} className="stack-form">
                    <label>Email address<input type="email" autoComplete="email" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; account_error = ""; }} placeholder="you@example.com" required={True} /></label>
                    <label>Password<input type="password" autoComplete={"new-password" if signup_mode else "current-password"} value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; account_error = ""; }} placeholder="At least 8 characters" required={True} minLength={8} /></label>
                    {if account_error { <div className="alert alert-error" role="alert">{account_error}</div> }}
                    <button className="button button-primary button-wide" type="submit" disabled={loading}>{"Creating account…" if loading and signup_mode else "Signing in…" if loading else "Create account" if signup_mode else "Sign in"}</button>
                </form>
                <p className="auth-switch">{"Already have an account?" if signup_mode else "New to RuhJac?"} <button className="text-button" onClick={lambda (e: MouseEvent) { signup_mode = not signup_mode; account_error = ""; }}>{"Sign in" if signup_mode else "Create an account"}</button></p>
                <p className="tiny muted">Your RuhJac account is separate from your school or LMS account.</p>
            </div></section>
        </main>;
    }

    today_date: str = local_today();
    shown_tasks: list[Task] = [item for item in tasks if not item.completed and not item.deleted];
    if active_view == "Completed" { shown_tasks = [item for item in tasks if item.completed and not item.deleted]; }
    elif active_view == "Courses" { shown_tasks = [item for item in tasks if not item.completed and not item.deleted and (task_course == "" or item.course == task_course)]; }
    elif active_view == "Today" { shown_tasks = [item for item in tasks if not item.completed and not item.deleted and (item.due == "" or item.due[:10] == today_date)]; }
    elif active_view == "Inbox" { shown_tasks = [item for item in tasks if not item.completed and not item.deleted and item.course == ""]; }
    elif active_view == "Upcoming" { shown_tasks = [item for item in tasks if not item.completed and not item.deleted and item.due != "" and item.due[:10] >= today_date]; }
    if query.strip() { shown_tasks = [item for item in shown_tasks if query.lower() in item.title.lower() or query.lower() in item.course.lower() or query.lower() in item.description.lower()]; }
    open_count: int = len([item for item in tasks if not item.completed and not item.deleted]);
    done_count: int = len([item for item in tasks if item.completed and not item.deleted]);
    due_tasks: list[Task] = [item for item in tasks if not item.completed and not item.deleted and item.due != ""];
    overdue_tasks: list[Task] = [item for item in due_tasks if item.due[:10] < today_date];

    return <div className="app-shell">
        <aside className="sidebar">
            <a className="brand" href="#"><span className="brand-mark">r</span> ruhjac</a>
            <div className="sidebar-label">WORKSPACE</div>
            <nav className="nav-list" aria-label="Planner views">
                <button className={"nav-item active" if active_view == "Moodle" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Moodle"; task_course = ""; }}><span className="nav-icon">▤</span> Moodle LMS</button>
                <button className={"nav-item active" if active_view == "Today" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Today"; task_course = ""; }}><span className="nav-icon">◷</span> Today <span className="nav-count">{open_count}</span></button>
                <button className={"nav-item active" if active_view == "Upcoming" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Upcoming"; task_course = ""; }}><span className="nav-icon">▦</span> Upcoming</button>
                <button className={"nav-item active" if active_view == "Courses" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Courses"; task_course = ""; }}><span className="nav-icon">◫</span> Courses</button>
                <button className={"nav-item active" if active_view == "Inbox" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Inbox"; task_course = ""; }}><span className="nav-icon">↳</span> Inbox</button>
                <button className={"nav-item active" if active_view == "Completed" else "nav-item"} onClick={lambda (e: MouseEvent) { active_view = "Completed"; task_course = ""; }}><span className="nav-icon">✓</span> Completed <span className="nav-count">{done_count}</span></button>
            </nav>
            <div className="sidebar-section"><div className="sidebar-label">YOUR COURSES <button aria-label="Add course" className="icon-button small" onClick={lambda (e: MouseEvent) { show_course_form = not show_course_form; }}>＋</button></div>
                {for course in courses { <button key={jid(course)} className="course-link" onClick={lambda (e: MouseEvent) { active_view = "Courses"; task_course = course.name; }}><span className="course-dot" style={{"backgroundColor": course.color}}></span><span>{course.code if course.code else course.name}</span></button> }}
                {if len(courses) == 0 { <div className="sidebar-empty">Add a course to keep work organized.</div> }}
            </div>
            <div className="sidebar-bottom"><div className="avatar">{email[:1].upper()}</div><div className="account-meta"><strong>{email}</strong><span>Personal workspace</span></div><button className="icon-button" aria-label="Sign out" onClick={sign_out}>↗</button></div>
        </aside>

        <main className="main-area">
            <header className="topbar"><div className="mobile-brand"><a className="brand" href="#"><span className="brand-mark">r</span> ruhjac</a></div><div className="crumb">My planner <span>/</span> <strong>{task_course if task_course else active_view}</strong></div><div className="top-actions"><label className="search-box"><span>⌕</span><input aria-label="Search tasks" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }} placeholder="Search tasks" /><kbd>⌘ K</kbd></label><button className="button button-primary button-small" onClick={open_new_task}>＋ <span>New task</span></button></div></header>
            <div className="content-wrap">
                {if notice { <div className="notice" role="status"><span>{notice}</span>{if deleted_task is not None { <button className="undo-button" onClick={restore_deleted}>Undo</button> }}<button className="icon-button small" aria-label="Dismiss message" onClick={lambda (e: MouseEvent) { notice = ""; deleted_task = None; }}>×</button></div> }}
                <div className="welcome-row"><div><span className="eyebrow">YOUR STUDY SPACE</span><h1>Good to see you</h1><p className="muted">A clear view of your coursework, all in one place.</p></div><button className="button button-soft" onClick={plan_day}><span>✳</span> Plan my day</button></div>
                {if active_view == "Moodle" { <MoodlePanel on_review={lambda (item: TaskDraft) { save_draft(item); }} /> }}
                {if active_view == "Assistant" { <section className="panel assistant-panel"><div className="panel-heading"><div><span className="eyebrow">YOUR STUDY PARTNER</span><h2>Ask RuhJac</h2></div><span className="assistant-spark">✦</span></div><p className="muted">Ask for a study plan, prioritization, or an explanation of assignment text. Only relevant planner details are sent with your request.</p><label className="focus-time">Available focus time (minutes)<input type="number" min="15" max="600" step="15" value={assistant_minutes} onChange={lambda (e: ChangeEvent) { assistant_minutes = e.target.value; }} /></label><form onSubmit={ask_assistant} className="assistant-form"><textarea value={assistant_prompt} onChange={lambda (e: ChangeEvent) { assistant_prompt = e.target.value; assistant_error = ""; }} placeholder="e.g. Help me break this research paper into steps…" rows={4}></textarea><button className="button button-primary" type="submit" disabled={assistant_loading}>{"Thinking…" if assistant_loading else "Ask assistant ↗"}</button></form>{if assistant_error { <div className="alert alert-error">{assistant_error}</div> }}{if assistant_reply is not None { <div className="assistant-answer"><p>{assistant_reply.message}</p>{for item in assistant_reply.tasks { <div key={str(item.title)} className="draft-row"><div><strong>{item.title}</strong><small>{item.estimate}m · {item.priority}{" · " + item.due if item.due else ""}</small></div><button className="button button-soft button-small" onClick={lambda (e: MouseEvent) { save_draft(item); }}>Review & add</button></div> }}</div> }}</section> }}
                {if active_view != "Moodle" { <div className="planner-overview"><section className="stats-grid" aria-label="Study overview">
                    <div className="stat-card"><div className="stat-icon lavender">◷</div><span className="stat-label">OPEN TASKS</span><strong>{open_count}</strong><small>ready when you are</small></div>
                    <div className="stat-card"><div className="stat-icon peach">⌁</div><span className="stat-label">OVERDUE</span><strong>{len(overdue_tasks)}</strong><small>ready for a fresh look</small></div>
                    <div className="stat-card"><div className="stat-icon mint">✓</div><span className="stat-label">COMPLETED</span><strong>{done_count}</strong><small>small steps add up</small></div>
                    <div className="stat-card progress-card"><div className="progress-top"><span className="stat-label">WEEKLY MOMENTUM</span><span className="progress-value">{f"{round(done_count * 100 / (done_count + open_count), 0):.0f}%" if done_count + open_count > 0 else "0%"}</span></div><div className="progress-track"><div className="progress-fill" style={{"width": f"{round(done_count * 100 / (done_count + open_count), 0) if done_count + open_count > 0 else 0}%"}}></div></div><small>{done_count} tasks wrapped up</small></div>
                </section>
                {if len(overdue_tasks) > 0 { <section className="overdue-banner"><div className="overdue-icon">!</div><div className="overdue-copy"><strong>{len(overdue_tasks)} {"task is" if len(overdue_tasks) == 1 else "tasks are"} past due</strong><span>Adjust the dates or take one small step to get moving again.</span></div><button className="link-button" onClick={lambda (e: MouseEvent) { active_view = "Upcoming"; }}>Review deadlines →</button></section> }}
                <section className="capture-card"><div className="capture-icon">✦</div><div className="capture-content"><strong>Quick capture</strong><p>Get it out of your head. Add the details after.</p></div><form className="capture-form" onSubmit={capture_task}><input value={quick_text} onChange={lambda (e: ChangeEvent) { quick_text = e.target.value; }} placeholder="e.g. Lab report Friday, 90 minutes, high priority" aria-label="Quick capture task" /><button className="button button-dark" type="submit">Add task <span>↗</span></button></form></section>
                <div className="section-grid">
                    <section className="panel task-panel"><div className="panel-heading"><div><span className="eyebrow">STAY ON TOP OF IT</span><h2>{active_view if not task_course else task_course}</h2></div><button className="link-button" onClick={lambda (e: MouseEvent) { active_view = "Upcoming"; task_course = ""; }}>View all <span>→</span></button></div>
                        {if len(shown_tasks) == 0 { <div className="empty-state"><div className="empty-illustration">✳</div><h3>{"All clear for now" if active_view != "Completed" else "Nothing completed yet"}</h3><p>{"Capture a task or add coursework to start building your plan." if active_view != "Completed" else "Completed tasks will find a home here."}</p><button className="button button-soft" onClick={open_new_task}>＋ Add your first task</button></div> }}
                        {for item in shown_tasks { <article key={jid(item)} className="task-row"><button className={"check-circle checked" if item.completed else "check-circle"} aria-label={"Reopen " + item.title if item.completed else "Complete " + item.title} onClick={lambda (e: MouseEvent) { toggle_task(item); }}>{"✓" if item.completed else ""}</button><button className="task-main" onClick={lambda (e: MouseEvent) { selected_task = item; }}><strong>{item.title}</strong><span>{item.course if item.course else "Inbox"}{" · " + item.due if item.due else ""}</span></button><span className={"priority priority-high" if item.priority == "High" else "priority priority-low" if item.priority == "Low" else "priority"}>{item.priority}</span><span className="effort">{item.estimate}m</span><button aria-label={"Edit " + item.title} className="icon-button task-edit" onClick={lambda (e: MouseEvent) { edit_task(item); }}>···</button></article> }}
                    </section>
                    <aside className="right-rail">
                        <section className="panel radar-panel"><div className="panel-heading"><div><span className="eyebrow">DEADLINE RADAR</span><h2>Coming up</h2></div><span className="radar-glyph">◉</span></div>
                            {if len(due_tasks) == 0 { <div className="radar-empty"><span>◎</span><p>Your next deadlines will appear here.</p></div> }}
                            {for item in due_tasks[:4] { <button key={jid(item)} className="deadline-row" onClick={lambda (e: MouseEvent) { selected_task = item; }}><span className={"deadline-marker marker-high" if item.priority == "High" else "deadline-marker"}></span><span className="deadline-info"><strong>{item.title}</strong><small>{item.course if item.course else "No course"}</small></span><span className="deadline-date">{item.due[:10]}</span></button> }}
                            <div className="radar-legend"><span className="legend-dot urgent"></span>High priority <span className="legend-dot normal"></span>Other work</div>
                        </section>
                        <section className="panel week-panel"><div className="panel-heading"><div><span className="eyebrow">A GENTLE NUDGE</span><h2>Your rhythm</h2></div><span className="week-icon">✧</span></div><div className="rhythm-art"><div className="rhythm-orbit orbit-one"></div><div className="rhythm-orbit orbit-two"></div><div className="rhythm-sun">✦</div><span className="orbit-dot dot-a"></span><span className="orbit-dot dot-b"></span></div><p className="rhythm-copy">Progress doesn’t need to be perfect. One focused step is a good place to begin.</p><button className="link-button assistant-link" onClick={lambda (e: MouseEvent) { active_view = "Assistant"; }}>Open study assistant <span>→</span></button></section>
                    </aside>
                </div></div> }}
            </div>
        </main>

        {if show_task_form { <div className="modal-backdrop" role="presentation"><section className="modal" role="dialog" aria-modal="true" aria-labelledby="task-form-title"><div className="modal-header"><div><span className="eyebrow">MAKE IT MANAGEABLE</span><h2 id="task-form-title">{"Edit task" if selected_task is not None else "New task"}</h2></div><button className="icon-button" aria-label="Close" onClick={lambda (e: MouseEvent) { show_task_form = False; selected_task = None; }}>×</button></div><form className="stack-form" onSubmit={save_task}><label>Task title<input value={task_title} onChange={lambda (e: ChangeEvent) { task_title = e.target.value; }} placeholder="What do you need to do?" required={True} /></label><label>Description <span className="optional">Optional</span><textarea value={task_description} onChange={lambda (e: ChangeEvent) { task_description = e.target.value; }} rows={3} placeholder="A little context helps future you."></textarea></label><div className="form-pair"><label>Course<select value={task_course} onChange={lambda (e: ChangeEvent) { task_course = e.target.value; }}><option value="">No course · Inbox</option>{if task_course and len([item for item in courses if item.name == task_course]) == 0 { <option value={task_course}>{task_course}</option> }}{for course in courses { <option key={jid(course)} value={course.name}>{course.code if course.code else course.name}</option> }}</select></label><label>Due date & time<input type="datetime-local" value={task_due} onChange={lambda (e: ChangeEvent) { task_due = e.target.value; }} /></label></div><div className="form-pair"><label>Priority<select value={task_priority} onChange={lambda (e: ChangeEvent) { task_priority = e.target.value; }}><option>Low</option><option>Medium</option><option>High</option></select></label><label>Estimated effort<input type="number" min="5" max="600" step="5" value={task_estimate} onChange={lambda (e: ChangeEvent) { task_estimate = e.target.value; }} /></label></div><label>Tags <span className="optional">Comma separated</span><input value={task_tags} onChange={lambda (e: ChangeEvent) { task_tags = e.target.value; }} placeholder="reading, exam prep" /></label>{if task_error { <div className="alert alert-error">{task_error}</div> }}<div className="modal-actions">{if selected_task is not None { <button type="button" className="button button-danger-quiet" onClick={remove_selected}>Delete task</button> }}<span></span><button type="button" className="button button-quiet" onClick={lambda (e: MouseEvent) { show_task_form = False; selected_task = None; }}>Cancel</button><button className="button button-primary" type="submit">Save task</button></div></form></section></div> }}
        {if selected_task is not None and not show_task_form { <div className="modal-backdrop" role="presentation"><section className="modal detail-modal" role="dialog" aria-modal="true"><div className="modal-header"><span className={"priority priority-high" if selected_task.priority == "High" else "priority"}>{selected_task.priority} priority</span><button className="icon-button" aria-label="Close" onClick={lambda (e: MouseEvent) { selected_task = None; }}>×</button></div><h2>{selected_task.title}</h2><p className="muted">{selected_task.description if selected_task.description else "No extra details yet."}</p><div className="detail-meta"><div><span>COURSE</span><strong>{selected_task.course if selected_task.course else "Inbox"}</strong></div><div><span>DUE</span><strong>{selected_task.due if selected_task.due else "No deadline"}</strong></div><div><span>EFFORT</span><strong>{selected_task.estimate} minutes</strong></div></div><div className="modal-actions"><button className="button button-soft" onClick={toggle_selected}>✓ {"Reopen task" if selected_task.completed else "Mark complete"}</button><span></span><button className="button button-primary" onClick={edit_selected}>Edit task</button></div></section></div> }}
        {if show_course_form { <div className="modal-backdrop" role="presentation"><section className="modal compact-modal" role="dialog" aria-modal="true"><div className="modal-header"><div><span className="eyebrow">STAY ORGANIZED</span><h2>Add a course</h2></div><button className="icon-button" onClick={lambda (e: MouseEvent) { show_course_form = False; }}>×</button></div><form className="stack-form" onSubmit={create_course}><label>Course name<input value={course_name} onChange={lambda (e: ChangeEvent) { course_name = e.target.value; }} placeholder="Introduction to Biology" required={True} /></label><label>Short code <span className="optional">Optional</span><input value={course_code} onChange={lambda (e: ChangeEvent) { course_code = e.target.value; }} placeholder="BIO 101" /></label><div className="modal-actions"><span></span><button type="button" className="button button-quiet" onClick={lambda (e: MouseEvent) { show_course_form = False; }}>Cancel</button><button className="button button-primary" type="submit">Add course</button></div></form></section></div> }}
    </div>;
}
