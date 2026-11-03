#!/usr/bin/env python3
"""Offline mutation checks for known session regressions, in a temporary copy.

Never edits the working tree. A killed mutant must compile and fail a test;
compiler errors, missing tests and unavailable dependencies are NOT passes.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CRATE = "crates/ginkgo_upstream/src/"
MUTATIONS = [
    ("reject-bykc-plaintext-envelope", "adapters/bykc_http.rs",
     "if envelope.is_object() {", "if false && envelope.is_object() {",
     "accepts_reference_plaintext_envelopes"),
    ("drop-redirect-negotiation", "auth/session.rs",
     "current.headers.extend(negotiation);", "drop(negotiation);",
     "session_protocol_redirect_keeps_negotiation"),
    ("omit-auth-default-accept", "auth/session.rs",
     'if request.header_value("Accept").is_none() {',
     'if false && request.header_value("Accept").is_none() {', "session_protocol"),
    ("omit-auth-form-charset", "auth/mod.rs",
     '"application/x-www-form-urlencoded; charset=UTF-8"',
     '"application/x-www-form-urlencoded"', "session_protocol"),
    ("skip-service-ticket", "auth/login.rs",
     "let target = redirect::resolve_get(location, &current_url)?;",
     "let target = redirect::resolve_get(location, &current_url)?; if !is_login_page_target(&target) { return Ok(None); }",
     "session_protocol"),
    ("fake-uc-identity", "auth/mod.rs", "let user = validate_session(session).await?;",
     'let user = UserProfile { school_id: credentials.username.trim().into(), name: "invented".into() };',
     "session_protocol"),
    ("unpin-authenticated-route", "auth/session.rs", "*route = RouteMode::Direct;",
     "*route = RouteMode::Automatic;", "session_protocol"),
    ("persist-preference-as-route", "services/session_service.rs",
     "            active_route,\n            self.session.cookie_snapshot(),",
     "            RouteMode::Automatic,\n            self.session.cookie_snapshot(),", "session_protocol"),
    ("lose-captcha-route", "services/session_service/session_source.rs",
     "self.session.set_route(page.route);", "self.session.set_route(self.preference().into());",
     "session_protocol"),
    ("password-before-uc-proof", "services/session_service.rs",
     "auth::validate_session(&self.session).await",
     "Err::<UserProfile, AppError>(AppError::session_expired())", "session_protocol"),
    ("drop-valued-form-input", "auth/cas.rs",
     'input_type == "hidden" || !value.trim().is_empty()', 'input_type == "hidden"',
     "ubaa_cas_oracle"),
    ("omit-ktor-json-accept", "adapters/schedule_http.rs",
     '"application/json, text/javascript, */*; q=0.01, application/json"',
     '"application/json, text/javascript, */*; q=0.01"', "reference_business_wire_capture"),
    ("normalize-empty-webvpn-path", "foundation/webvpn.rs",
     'format!("https://{GATEWAY_HOST}/{protocol}/{encoded_host}{path}")',
     'format!("https://{GATEWAY_HOST}/{protocol}/{encoded_host}{}", url.path())', "reference_business_wire_capture"),
    ("optional-password-blocks-cookie-restore", "services/session_service/session_source.rs",
     "let remembered =\n                                self.vault.load(&account).is_ok_and(|entry| entry.is_some());",
     "let remembered = self.vault.load(&account)?.is_some();",
     "session_protocol_valid_cookies_do_not_depend_on_optional_password_storage"),
    ("accept-unverified-gateway-identity", "auth/session/automatic_route.rs",
     ".and_then(uc::validate_response)",
     '.and_then(|_| Ok(UserProfile { school_id: "sy2501001".into(), name: "invented".into() }))',
     "session_protocol_automatic_route_failure"),
    ("replay-old-module-credentials-after-route-change", "auth/session/automatic_route.rs",
     "if has_module_credentials(&request) {", "if false && has_module_credentials(&request) {",
     "session_protocol_automatic_route_rebuilds_checkin_at_every_read_stage"),
    ("caller-cookie-case-leak", "auth/session.rs",
     '.retain(|name, _| !name.eq_ignore_ascii_case("cookie"));', '.retain(|name, _| name != "Cookie");',
     "session_protocol_cookie_headers_are_owned_case_insensitively"),
    ("request-time-cookie-expiry", "auth/session.rs",
     "jar.store(&request_url, header, received_at);", "jar.store(&request_url, header, now);",
     "network:actual_cookie_max_age_starts_at_response_arrival"),
    ("foreign-domain-cookie-return", "foundation/cookie.rs",
     """                    } else if !candidate.is_empty() {
                        // An invalid Domain rejects the cookie. Treating it
                        // as host-only sends a foreign cookie back to origin.
                        return;
                    }""",
     "                    }", "network:transport_loopback_reference_capture"),
    ("default-user-agent-drift", "adapters/reqwest_transport.rs",
     'const USER_AGENT: &str = "ktor-client";', 'const USER_AGENT: &str = "synthetic-regression";',
     "network:transport_loopback_reference_capture"),
    ("implicit-compression-drift", "adapters/reqwest_transport.rs",
     ".gzip(true)", ".gzip(false)", "network:transport_loopback_reference_capture"),
    ("orphan-http-task-after-cancel", "adapters/reqwest_transport.rs",
     "self.0.abort();", "let _ = &self.0;",
     "network:actual_request_deadline_and_future_cancellation_close_the_socket"),
]


def run(workspace, selection):
    env = dict(os.environ, CARGO_NET_OFFLINE="true", CARGO_TARGET_DIR=str(ROOT / "rust/target"))
    command = ["cargo", "test", "--offline", "--locked", "-p", "ginkgo_upstream"]
    if selection.startswith("network:"):
        selection = selection.removeprefix("network:")
        command += ["--features", "network"]
        command += ["--test", "transport_loopback"] if selection == "transport_loopback_reference_capture" else ["--lib"]
    else:
        command += ["--no-default-features", "--lib"]
    result = subprocess.run(command + [selection],
                            cwd=workspace, env=env, text=True, capture_output=True, timeout=180)
    return result, result.stdout + result.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    results = []
    with tempfile.TemporaryDirectory(prefix="ginkgo-session-mutants-") as temporary:
        scratch = Path(temporary)
        shutil.copytree(ROOT / "rust", scratch / "rust", ignore=shutil.ignore_patterns("target"))
        shutil.copytree(ROOT / "fixtures", scratch / "fixtures")
        for selection in ["session_protocol", "ubaa_cas_oracle", "reference_business_wire_capture", "accepts_reference_plaintext_envelopes", "network:transport_loopback_reference_capture", "network:lifecycle_tests"]:
            result, output = run(scratch / "rust", selection)
            if result.returncode or not re.search(r"test result: ok\. [1-9]\d* passed", output):
                raise SystemExit(f"Baseline {selection} failed; no mutation result claimed\n{output}")
        print("Temporary-copy baseline passed", flush=True)
        for name, filename, old, new, selection in MUTATIONS:
            path = scratch / "rust" / CRATE / filename
            original = path.read_text()
            if original.count(old) != 1:
                raise SystemExit(f"Mutation anchor changed: {name}; review before updating")
            try:
                path.write_text(original.replace(old, new))
                result, output = run(scratch / "rust", selection)
            finally:
                path.write_text(original)
            detected = result.returncode != 0 and "test result: FAILED" in output
            failures = re.findall(r"^test (\S+) \.\.\. FAILED$", output, re.MULTILINE)
            results.append({"mutation": name, "detected_by_test": detected, "failures": failures})
            print(f"{name}: {'caught by test' if detected else 'FAILED TO DETECT'}", flush=True)
            if not detected:
                raise SystemExit(output)
    if args.report:
        args.report.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(results)}/{len(results)} compiling regressions detected; working sources unchanged")


if __name__ == "__main__":
    main()
