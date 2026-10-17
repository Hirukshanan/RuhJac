# RuhJac

RuhJac is a student task and study planner built as a full-stack Jac 0.34.1 web app. It includes account creation and sign-in, a private task and course planner, and an optional server-side Gemini study assistant. Each account's tasks and courses are stored on its isolated Jac graph.

## Requirements

- Jac 0.34.1 (`jac --version`)
- Bun (used by Jac to build the browser client)
- Node.js 20 or newer (used by the Vite development server)
- A modern browser
- Optional: a Gemini API key for quick-capture parsing and study assistance

## Run in VS Code

1. Open this folder in VS Code.
2. In the integrated terminal, install dependencies:

   ```sh
   jac install
   ```

3. To enable Gemini, copy `.env.example` to `.env`, add your API key, and load it in the terminal before starting the app:

   ```sh
   cp .env.example .env
   # Edit .env, then:
   set -a
   source .env
   set +a
   ```

   Keep `.env` private. Never add a real key to Jac source or browser code. The default model is configured as `gemini/gemini-3.8-flash`; set `GEMINI_MODEL` to a Google-supported model identifier if that model is unavailable to your account or provider.

4. Start the app:

   ```sh
   jac start --dev main.jac
   ```

   Open the local URL printed by Jac (usually `http://localhost:8000`). Stop it with Ctrl+C.

Without a Gemini key, account, course, and task management still work. Quick capture opens an editable manual task form if parsing is unavailable, and assistant requests show a helpful service error. User accounts and password hashes are handled by Jac's built-in authentication layer. Your faculty Moodle password is entered only on the faculty website.

Local password reset email delivery is not configured. To enable reset links, configure a Jac-compatible emailer for the deployed environment.

## Using the planner

- Create an account with your email and a password, or sign in to an existing RuhJac account.
- Add courses with the plus next to **Your courses**.
- Use **New task** for a complete task form, or **Quick capture** for natural-language parsing. Always review parsed details before saving.
- Complete a task with its circle; reopen it from the Completed view. Task details can be opened, edited, or removed.
- Search tasks from the top bar; use Today, Upcoming, Courses, Inbox, and Completed to focus the list.
- Open **Plan my day** to focus the task view. Use **Open study assistant** to ask about your task list or paste assignment text. Assistant suggestions are drafts and require your review before saving.
- Open **Moodle LMS** to connect your faculty account, select an enrolled course, choose materials, and request a course analysis.

## Faculty Moodle connection

1. Sign in to RuhJac, then select **Moodle LMS** in the sidebar.
2. Use **Sign in to faculty Moodle** to sign in on `https://elms.eng.ruh.ac.lk/login/index.php` in a separate browser tab. RuhJac does not embed or automate the login page, read Moodle cookies, or request your Moodle password.
3. Obtain a Moodle web-service token from **Security keys** if your account can access that page, or request one from your faculty LMS administrator. Paste it into the **Moodle access token** field and click **Connect Moodle**. A normal Moodle browser session alone is insufficient for API access.
4. Choose one of your enrolled courses. Select the materials the agent may read and click **Analyse selected materials**. Only then are the selected text and the course overview sent to Gemini.
5. Review the summary, coverage notes, and suggested tasks. **Review & add** opens an editable task form; tasks are saved only when you press **Save task**.

The faculty must enable HTTPS Moodle REST web services and authorise a token for the following read functions:

- Required: `core_webservice_get_site_info`, `core_enrol_get_users_courses`, `core_course_get_contents`.
- Optional for richer analysis: `mod_page_get_pages_by_courses`, `mod_assign_get_assignments`.

Ask the administrator to use a service containing only those read functions and the permissions appropriate to your student account. RuhJac verifies enrolment again before reading a course and excludes activities marked inaccessible to the current account. Faculty API availability has not been verified with an authorised token; enabling it requires the faculty administrator. Moodle documentation: [web-service setup](https://docs.moodle.org/405/en/Using_web_services).

Analysis covers selected course/section descriptions, Moodle page bodies, and assignment instructions/deadlines when the API grants access. PDFs and other attached files, videos, forums, quizzes, and external links are listed only; their full contents are not read. The UI and analysis coverage notes make these limits explicit. Analysis is capped at 80 selected materials and 24,000 characters of source context; omitted text is reported. Deadline timestamps are rendered in Asia/Colombo.

Tokens are sent to the configured Moodle host over HTTPS and kept in server memory, scoped to the signed-in RuhJac account. Connections expire after one hour; expired entries are removed on access or the next successful connection. Tokens are never returned in API responses, saved to the graph/database, put in browser storage, or sent to Gemini. The input is cleared after connecting. **Disconnect** and RuhJac sign-out remove the server session; expiry and restarting the server also require reconnecting. This simple session store supports one server process; reconnect if requests move between workers. Disconnect removes the Moodle connection and clears the panel; tasks you explicitly saved remain normal planner tasks and can be deleted in the planner. Revoke the token in Moodle to invalidate it at the faculty server.

The allowed host defaults to `elms.eng.ruh.ac.lk`. Set server environment variable `MOODLE_HOST` to an administrator-approved hostname to connect another faculty site. Requests cannot redirect to another host. No Moodle write, grade, submission, or user-management API is called.

## Data and privacy

Jac stores graph data locally in `.jac/data` by default. Authenticated `def:protect` endpoints run against the signed-in account's isolated graph, so one user cannot query another account's tasks or courses. Sign out from the account control at the bottom of the sidebar. Local development data and the auth database are private machine data; do not commit `.jac/data/`. Moodle course previews and analysis results are temporary; only task drafts you explicitly save are persisted.

## Gemini integration

Gemini calls run only in Jac server functions and use `GEMINI_API_KEY` from the server environment. The browser sends the assistant only when the user submits a request; the assistant endpoint includes up to 20 task titles, course names, due dates, effort estimates, and statuses as context. Pasted assignment text is treated as untrusted reference data. The model returns typed draft objects; it cannot mutate planner data, and a user must explicitly save each draft. Invalid output is validated through Jac's structured LLM return type; API failures are surfaced without blocking the planner.

The requested model ID is set to `gemini-3.8-flash` (LiteLLM/Jac provider form `gemini/gemini-3.8-flash`) and can be changed with `GEMINI_MODEL`. Model availability depends on the Google account and the provider version installed with Jac.

For a production deployment, set a long random `JWT_SECRET` in the server environment. Keep all `.env` and `.jac/data` files out of source control.

## Project layout

- `main.jac` — full-stack app entry point
- `frontend.cl.jac`, `frontend.impl.jac` — planner UI and client interactions
- `endpoints.jac` — isolated account data endpoints and Gemini boundary
- `moodle.jac`, `moodle.test.jac` — authenticated Moodle API boundary and checks
- `lms_panel.cl.jac` — Moodle connection, course selection, and analysis UI
- `styles/global.css` — responsive visual design
- `jac.toml` — Jac project and server-only LLM configuration
