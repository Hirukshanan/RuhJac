import from unittest.mock { patch, Mock }
import from contextlib { AbstractContextManager }

test "Moodle connection only accepts the configured HTTPS faculty site" {
    assert _moodle_site("https://elms.eng.ruh.ac.lk/login/index.php") == "https://elms.eng.ruh.ac.lk";
    for url in ["http://elms.eng.ruh.ac.lk", "https://other.example", "https://elms.eng.ruh.ac.lk@other.example", "https://elms.eng.ruh.ac.lk:8443"] {
        try { _ = _moodle_site(url); assert False, "unapproved Moodle address accepted"; }
        except ValueError { assert True; }
    }
    assert _moodle_safe_link("javascript:alert(1)", "https://elms.eng.ruh.ac.lk") == "";
    assert _moodle_safe_link("https://elms.eng.ruh.ac.lk/file?token=secret", "https://elms.eng.ruh.ac.lk") == "";
    assert _moodle_text("<script>unsafe()</script><p>Week &amp; topic</p>") == "Week & topic";
    assert _NoMoodleRedirect().redirect_request(Request("https://elms.eng.ruh.ac.lk"), None, 302, "Found", {}, "https://other.example") is None;
}

test "Moodle API token stays server-side and disconnect removes the session" {
    _ = disconnect_moodle();
    call = Mock(side_effect=[{"userid": 12, "fullname": "Student", "functions": []}, [{"id": 34, "fullname": "Circuits", "shortname": "EE101"}]]);
    with (patch.dict(_moodle_call.__globals__, {"_moodle_call": call}) as AbstractContextManager) {
        connected = connect_moodle("https://elms.eng.ruh.ac.lk/login/index.php", "a" * 32);
        assert connected.connected, connected.error;
        assert connected.courses[0].id == 34;
        assert not hasattr(connected, "token");
        assert _moodle_session().user_id == 12;
    }
    assert disconnect_moodle();
    assert not moodle_status().connected;
}

test "Course reads enforce enrolment before fetching contents" {
    session = _MoodleSession(site="https://elms.eng.ruh.ac.lk", token="a" * 32, user_id=12, name="Student", expires=time() + 3600);
    call = Mock(return_value=[{"id": 34, "fullname": "Circuits"}]);
    with (patch.dict(_moodle_contents.__globals__, {"_moodle_call": call}) as AbstractContextManager) {
        try { _ = _moodle_contents(session, 999); assert False, "unenrolled course accepted"; }
        except ValueError { assert True; }
        assert call.call_count == 1;
    }
}

test "Course preview excludes inaccessible modules and sections" {
    session = _MoodleSession(site="https://elms.eng.ruh.ac.lk", token="a" * 32, user_id=12, name="Student", expires=time() + 3600);
    outline = [{"id": 1, "name": "Week 1", "modules": [{"id": 10, "name": "Lecture", "modname": "page", "description": "<p>Ohm’s law</p>", "uservisible": True}, {"id": 11, "name": "Locked activity", "uservisible": False}]}, {"id": 2, "name": "Hidden week", "uservisible": False, "modules": [{"id": 20, "name": "Private notes"}]}];
    call = Mock(side_effect=[[{"id": 34, "fullname": "Circuits"}], outline]);
    with (patch.dict(_moodle_contents.__globals__, {"_moodle_call": call}) as AbstractContextManager) {
        content = _moodle_contents(session, 34);
        assert len(content.materials) == 1;
        assert content.materials[0].id == 10;
        assert content.materials[0].description == "Ohm’s law";
    }
}

test "Only selected accessible materials reach the course analysis" {
    _moodle_sessions[jid(root)] = _MoodleSession(site="https://elms.eng.ruh.ac.lk", token="a" * 32, user_id=12, name="Student", expires=time() + 3600);
    preview = MoodleCourseContent(course_id=34, name="Circuits", materials=[MoodleMaterial(id=10, name="Lecture", description="Ohm’s law"), MoodleMaterial(id=11, name="Unselected", description="Unselected private content")]);
    model = Mock();
    with (patch.dict(analyse_moodle_course.__globals__, {"_moodle_contents": Mock(return_value=preview), "_study_answer": model}) as AbstractContextManager) {
        denied = analyse_moodle_course(34, [999], "");
        assert denied.error;
        assert model.call_count == 0;
    }
    model = Mock(return_value=StudyReply(message="Review Ohm’s law."));
    with (patch.dict(analyse_moodle_course.__globals__, {"_moodle_contents": Mock(return_value=preview), "_moodle_enrich": Mock(return_value="Descriptions only."), "_study_answer": model}) as AbstractContextManager) {
        answer = analyse_moodle_course(34, [10], "Help me study");
        assert answer.reply is not None;
        assert answer.reply.message == "Review Ohm’s law.";
        assert model.call_count == 1;
        assert "Ohm’s law" in str(model.call_args);
        assert "Unselected private content" not in str(model.call_args);
    }
    _ = disconnect_moodle();
}

test "Expired Moodle sessions must reconnect" {
    _moodle_sessions[jid(root)] = _MoodleSession(site="https://elms.eng.ruh.ac.lk", token="a" * 32, user_id=12, name="Student", expires=time() - 1);
    try { _ = _moodle_session(); assert False, "expired session accepted"; }
    except ValueError { assert True; }
    assert jid(root) not in _moodle_sessions;
}

test "A different RuhJac account cannot reuse another account's Moodle connection" {
    _moodle_sessions[jid(root)] = _MoodleSession(site="https://elms.eng.ruh.ac.lk", token="a" * 32, user_id=12, name="Student", expires=time() + 3600);
    with (patch.dict(_moodle_session.__globals__, {"jid": Mock(return_value="another-account")}) as AbstractContextManager) {
        assert not moodle_status().connected;
        try { _ = _moodle_session(); assert False, "another account's connection leaked"; }
        except ValueError { assert True; }
    }
    _ = disconnect_moodle();
}
