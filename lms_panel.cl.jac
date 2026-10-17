"""Connect a faculty Moodle account and analyse explicitly selected course materials."""

sv import from moodle { MoodleConnection, MoodleCourseContent, MoodleAnalysis, connect_moodle, moodle_status, disconnect_moodle, moodle_course_content, analyse_moodle_course }
sv import from endpoints { TaskDraft }

def:pub MoodlePanel(on_review: Callable[[TaskDraft], None]) -> JsxElement {
    has connection: MoodleConnection | None = None,
        url: str = "https://elms.eng.ruh.ac.lk/login/index.php",
        token: str = "",
        course_id: str = "",
        content: MoodleCourseContent | None = None,
        selected: list[int] = [],
        question: str = "",
        analysis: MoodleAnalysis | None = None,
        busy: bool = False,
        analysing: bool = False,
        error: str = "";

    async can with entry { await refresh_courses(); }

    async def refresh_courses() -> None {
        busy = True;
        error = "";
        try {
            current = await moodle_status();
            connection = current;
            error = current.error;
            if not current.connected { content = None; selected = []; analysis = None; course_id = ""; }
        } except Exception { error = "Couldn’t check your Moodle connection. Try again."; }
        busy = False;
    }

    async def connect(e: FormEvent) -> None {
        e.preventDefault();
        busy = True;
        error = "";
        try {
            current = await connect_moodle(url, token);
            connection = current;
            error = current.error;
            content = None;
            selected = [];
            analysis = None;
            course_id = "";
        } except Exception { error = "Couldn’t connect to Moodle. Check that RuhJac is running and try again."; }
        token = "";
        busy = False;
    }

    async def disconnect(e: MouseEvent) -> None {
        busy = True;
        try {
            _ = await disconnect_moodle();
            connection = None;
            content = None;
            selected = [];
            analysis = None;
            course_id = "";
            token = "";
            question = "";
            error = "";
        } except Exception { error = "Couldn’t disconnect. Try again."; }
        busy = False;
    }

    async def load_course(value: str) -> None {
        course_id = value;
        content = None;
        selected = [];
        analysis = None;
        error = "";
        if not value { return; }
        busy = True;
        try {
            loaded = await moodle_course_content(int(value));
            content = loaded;
            error = loaded.error;
        } except Exception { error = "Couldn’t load this course. Refresh the course list and try again."; }
        busy = False;
    }

    def toggle_material(material_id: int) -> None {
        selected = [item for item in selected if item != material_id] if material_id in selected else selected + [material_id];
        analysis = None;
    }

    async def analyse(e: FormEvent) -> None {
        e.preventDefault();
        analysing = True;
        analysis = None;
        error = "";
        try {
            result = await analyse_moodle_course(int(course_id), selected, question);
            analysis = result;
            error = result.error;
        } except Exception { error = "Couldn’t analyse this course. Please try again."; }
        analysing = False;
    }

    return <section className="panel moodle-panel" aria-labelledby="moodle-title">
        <div className="panel-heading"><div><span className="eyebrow">YOUR FACULTY LMS</span><h2 id="moodle-title">Moodle courses</h2></div><span className="moodle-badge">Read only</span></div>
        {if error { <div className="alert alert-error" role="alert">{error}</div> }}
        {if connection is None or not connection.connected {
            <div className="moodle-connect-grid">
                <div className="moodle-intro"><h3>Bring your coursework into focus.</h3><p className="muted">Sign in on your faculty’s Moodle website, then connect using a web-service token issued for your account.</p><a className="button button-soft" href="https://elms.eng.ruh.ac.lk/login/index.php" target="_blank" rel="noreferrer">Sign in to faculty Moodle ↗</a><p className="muted">Your faculty must enable Moodle REST web services and grant access to your enrolled courses. A browser login alone cannot connect RuhJac.</p><a className="link-button" href="https://elms.eng.ruh.ac.lk/user/managetoken.php" target="_blank" rel="noreferrer">Open Moodle security keys ↗</a><p className="muted">If security keys are unavailable, ask your LMS administrator for an authorised web-service token. Keep your Moodle password on the faculty website.</p></div>
                <form className="stack-form" onSubmit={connect}>
                    <label>Faculty LMS URL<input type="url" value={url} onChange={lambda (e: ChangeEvent) { url = e.target.value; }} required={True} /></label>
                    <label>Moodle access token<input type="password" autoComplete="off" value={token} onChange={lambda (e: ChangeEvent) { token = e.target.value; }} placeholder="Your authorised web-service token" required={True} maxLength={256} /></label>
                    <p className="muted">Your token stays on the RuhJac server. The connection expires after one hour; disconnect to clear it. Connect again after a server restart.</p>
                    <button className="button button-primary" type="submit" disabled={busy}>{"Connecting…" if busy else "Connect Moodle"}</button>
                </form>
            </div>
        } else {
            <div className="moodle-live">
            <div className="moodle-connected"><div><strong>{connection.name}</strong><span className="muted">{connection.site} · {len(connection.courses)} enrolled courses</span></div><div className="moodle-actions"><button className="button button-quiet" onClick={lambda (e: MouseEvent) { refresh_courses(); }} disabled={busy or analysing}>Refresh courses</button><button className="button button-quiet" onClick={disconnect} disabled={busy or analysing}>Disconnect</button></div></div>
            <label className="stack-form moodle-course-picker">Choose a course<select value={course_id} onChange={lambda (e: ChangeEvent) { load_course(e.target.value); }} disabled={busy or analysing}><option value="">Select one of your enrolled courses</option>{for course in connection.courses { <option key={str(course.id)} value={str(course.id)}>{course.code + " · " if course.code else ""}{course.name}</option> }}</select></label>
            {if len(connection.courses) == 0 { <p className="muted">Moodle returned no enrolled courses for this token. Check that it belongs to your student account.</p> }}
            {if busy { <p className="muted" role="status">Loading Moodle…</p> }}
            {if content is not None and not content.error {
                <div className="moodle-course-content"><h3>{content.name}</h3>{if content.summary { <p className="muted">{content.summary}</p> }}
                    <div className="moodle-selection-bar"><strong>Select materials for the agent</strong><div className="moodle-actions"><button className="text-button" disabled={analysing} onClick={lambda (e: MouseEvent) { if content is not None { selected = [item.id for item in content.materials[:80]]; analysis = None; } }}>Select all (up to 80)</button><button className="text-button" disabled={analysing} onClick={lambda (e: MouseEvent) { selected = []; analysis = None; }}>Clear</button></div></div>
                    {if len(content.materials) == 0 { <p className="muted">There are no materials available to your account in this course.</p> }}
                    <div className="moodle-materials">{for material in content.materials {
                        <article key={str(material.id)} className="moodle-material"><label><input type="checkbox" checked={material.id in selected} onChange={lambda (e: ChangeEvent) { toggle_material(material.id); }} disabled={analysing} /><span><strong>{material.name}</strong><small>{material.section} · {material.kind}</small></span></label>{if material.description { <p>{material.description[:350]}</p> }}{if material.files { <small>Files: {material.files}</small> }}{if material.url { <a className="link-button" href={material.url} target="_blank" rel="noreferrer">Open in Moodle ↗</a> }}</article>
                    }}</div>
                    <form onSubmit={analyse} className="stack-form moodle-analysis-form"><label>What would you like to understand? <span className="optional">Optional</span><textarea value={question} onChange={lambda (e: ChangeEvent) { question = e.target.value; }} rows={3} maxLength={2000} placeholder="Explain the main topics and help me prepare for this week’s work." disabled={analysing}></textarea></label><p className="muted">When you click Analyse, the selected material text and course overview are sent to Gemini. The agent reads course descriptions, available page text and assignment instructions. Attached files and external links are listed; their full contents are not read.</p><button className="button button-primary" type="submit" disabled={analysing or busy or len(selected) == 0}>{"Analysing selected materials…" if analysing else "Analyse selected materials (" + str(len(selected)) + ")"}</button></form>
                    {if analysing { <p className="muted" role="status">Reading your selected course materials and preparing a study plan…</p> }}
                    {if analysis is not None {
                        <div className="moodle-analysis-result">{if analysis.coverage { <p className="muted">{analysis.coverage}</p> }}{if analysis.reply is not None { <div className="assistant-answer"><p>{analysis.reply.message}</p>{for item in analysis.reply.tasks { <div key={item.title} className="draft-row"><div><strong>{item.title}</strong><small>{item.estimate}m · {item.priority}{" · " + item.due if item.due else ""}</small></div><button className="button button-soft button-small" onClick={lambda (e: MouseEvent) { on_review(item); }}>Review & add</button></div> }}</div> }}</div>
                    }}
                </div>
            }}
            </div>
        }}
    </section>;
}
