//! Execute the production transport against a bounded IPv4 loopback server.
#![cfg(feature = "network")]
use base64::{engine::general_purpose::STANDARD, Engine};
use ginkgo_upstream::{
    adapters::reqwest_transport::ReqwestTransport,
    auth::session::{RouteMode, Session},
    foundation::http::{HttpMethod, HttpRequest},
};
use serde_json::{json, Value};
use std::{
    collections::BTreeMap,
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    time::{Duration, Instant},
};

fn read_request(socket: &mut TcpStream) -> Value {
    socket.set_nonblocking(false).unwrap();
    socket
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let mut bytes = Vec::new();
    let (end, length) = loop {
        let mut buffer = [0; 4096];
        let n = socket.read(&mut buffer).unwrap();
        assert!(n > 0 && bytes.len() + n < 64 * 1024);
        bytes.extend_from_slice(&buffer[..n]);
        if let Some(end) = bytes.windows(4).position(|b| b == b"\r\n\r\n") {
            let header = String::from_utf8_lossy(&bytes[..end]);
            let length = header
                .lines()
                .find_map(|line| {
                    line.to_ascii_lowercase()
                        .strip_prefix("content-length:")
                        .map(|value| value.trim().parse::<usize>().unwrap())
                })
                .unwrap_or(0);
            break (end, length);
        }
    };
    while bytes.len() < end + 4 + length {
        let mut buffer = [0; 4096];
        let n = socket.read(&mut buffer).unwrap();
        assert!(n > 0 && bytes.len() + n < 64 * 1024);
        bytes.extend_from_slice(&buffer[..n]);
    }
    let header = String::from_utf8(bytes[..end].to_vec()).unwrap();
    let mut lines = header.lines();
    let parts: Vec<_> = lines.next().unwrap().split_whitespace().collect();
    let mut headers = BTreeMap::<String, String>::new();
    for line in lines {
        let (name, value) = line.split_once(':').unwrap();
        headers
            .entry(name.to_ascii_lowercase())
            .and_modify(|old| {
                old.push_str(", ");
                old.push_str(value.trim());
            })
            .or_insert_with(|| value.trim().into());
    }
    json!({"method":parts[0], "target":parts[1], "version":parts[2], "headers":headers, "body_base64":STANDARD.encode(&bytes[end+4..end+4+length])})
}

#[test]
fn transport_loopback_reference_capture() {
    let fixture: Value =
        serde_json::from_str(include_str!("data/http-loopback-cases.json")).unwrap();
    let cases = fixture["cases"].as_array().unwrap().clone();
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let base = format!("http://{}", listener.local_addr().unwrap());
    let scripted = cases.clone();
    let server = std::thread::spawn(move || {
        let mut captured = Vec::new();
        for case in scripted {
            let started = Instant::now();
            let mut socket = loop {
                match listener.accept() {
                    Ok((socket, _)) => break socket,
                    Err(error)
                        if error.kind() == std::io::ErrorKind::WouldBlock
                            && started.elapsed() < Duration::from_secs(5) =>
                    {
                        std::thread::sleep(Duration::from_millis(2))
                    }
                    Err(error) => panic!("loopback accept: {error}"),
                }
            };
            let request = read_request(&mut socket);
            assert_eq!(request["method"], case["method"]);
            assert_eq!(request["target"], case["path"]);
            let response = &case["response"];
            let bytes = response["base64"]
                .as_str()
                .map(|s| STANDARD.decode(s).unwrap())
                .unwrap_or_else(|| response["body"].as_str().unwrap().as_bytes().to_vec());
            let mut head = format!("HTTP/1.1 {} Synthetic\r\nContent-Length: {}\r\nConnection: close\r\nContent-Type: text/plain; charset=utf-8\r\n", response["status"], bytes.len());
            for header in response["headers"].as_array().unwrap() {
                head.push_str(&format!(
                    "{}: {}\r\n",
                    header[0].as_str().unwrap(),
                    header[1].as_str().unwrap()
                ));
            }
            socket.write_all(format!("{head}\r\n").as_bytes()).unwrap();
            socket.write_all(&bytes).unwrap();
            captured.push(json!({"id":case["id"],"request":request}));
        }
        captured
    });
    let transport = ReqwestTransport::new().unwrap();
    let session = Session::new(transport);
    session.set_route(RouteMode::Direct);
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let mut results = Vec::new();
    for case in &cases {
        let mut request = HttpRequest::new(
            if case["method"] == "POST" {
                HttpMethod::Post
            } else {
                HttpMethod::Get
            },
            format!("{base}{}", case["path"].as_str().unwrap()),
        );
        for (key, value) in case["headers"].as_object().unwrap() {
            request = request.header(key, value.as_str().unwrap());
        }
        if case["method"] == "POST" {
            request.body = Some(case["body"].as_str().unwrap().into());
        }
        request.binary_response = true;
        let response = runtime.block_on(session.send(request)).unwrap();
        assert_eq!(
            response.status,
            case["response"]["status"].as_u64().unwrap() as u16
        );
        let expected = case["response"]["base64"]
            .as_str()
            .map(|s| STANDARD.decode(s).unwrap())
            .unwrap_or_else(|| {
                case["response"]["body"]
                    .as_str()
                    .unwrap()
                    .as_bytes()
                    .to_vec()
            });
        assert_eq!(response.bytes.as_ref().unwrap(), &expected);
        results.push(json!({"id":case["id"],"status":response.status,"body_base64":STANDARD.encode(response.bytes.as_ref().unwrap()),"location":response.header("location"),"set_cookies":response.set_cookies}));
    }
    let captured = server.join().unwrap();
    let evidence =
        json!({"source":"synthetic","engine":"reqwest","requests":captured,"results":results});
    if let Some(path) = std::env::var_os("GINKGO_TRANSPORT_WIRE") {
        std::fs::write(path, serde_json::to_vec_pretty(&evidence).unwrap()).unwrap();
    }
    let cookie = captured[2]["request"]["headers"]["cookie"]
        .as_str()
        .unwrap();
    assert!(
        !cookie.contains("bad="),
        "a foreign-domain response cookie must never return to this origin: {cookie}"
    );
    assert!(!cookie.contains("gone=") && !cookie.contains("secret="));
    assert!(cookie.contains("scope=path") && cookie.contains("root=old"));
    // The golden is the actual independent Android-OkHttp-on-JVM capture, never regenerated by
    // this test. The one deliberately stricter path-boundary rule is explicit.
    let golden: Value =
        serde_json::from_str(include_str!("data/ubaa-transport-wire.json")).unwrap();
    let mut differences = Vec::new();
    for (reference, actual) in golden["requests"].as_array().unwrap().iter().zip(&captured) {
        assert_eq!(reference["id"], actual["id"]);
        let reference = canonical(&reference["request"]);
        let actual_request = canonical(&actual["request"]);
        for field in ["method", "target", "version", "body_base64"] {
            assert_eq!(
                reference[field], actual_request[field],
                "{} {field}",
                actual["id"]
            );
        }
        let left = reference["headers"].as_object().unwrap();
        let right = actual_request["headers"].as_object().unwrap();
        let names: std::collections::BTreeSet<_> = left.keys().chain(right.keys()).collect();
        for name in names {
            if left.get(name) != right.get(name) {
                differences.push(json!({"case":actual["id"],"field":format!("headers.{name}"),"ubaa":left.get(name),"rust":right.get(name)}));
            }
        }
    }
    assert_eq!(captured.len(), golden["requests"].as_array().unwrap().len());
    assert_eq!(
        differences,
        *golden["intentional_differences"].as_array().unwrap()
    );
    assert_eq!(evidence["results"], golden["results"]);
}

fn canonical(request: &Value) -> Value {
    let mut request = request.clone();
    let headers = request["headers"].as_object_mut().unwrap();
    headers.insert("host".into(), json!("127.0.0.1:<ephemeral>"));
    if let Some(cookie) = headers.get("cookie").and_then(Value::as_str) {
        let mut pairs: Vec<_> = cookie.split(';').map(str::trim).collect();
        pairs.sort();
        headers.insert("cookie".into(), json!(pairs));
    }
    request
}
