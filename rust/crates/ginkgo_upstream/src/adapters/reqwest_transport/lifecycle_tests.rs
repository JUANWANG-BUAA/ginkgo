//! Real socket boundaries; every listener binds IPv4 loopback only.
use super::*;
use std::{
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    sync::mpsc,
};

fn accept_request(listener: &TcpListener) -> (TcpStream, Vec<u8>) {
    listener.set_nonblocking(true).unwrap();
    let started = std::time::Instant::now();
    let mut socket = loop {
        match listener.accept() {
            Ok((socket, _)) => break socket,
            Err(error)
                if error.kind() == std::io::ErrorKind::WouldBlock
                    && started.elapsed() < Duration::from_secs(3) =>
            {
                std::thread::sleep(Duration::from_millis(2))
            }
            Err(error) => panic!("loopback accept failed: {error}"),
        }
    };
    socket.set_nonblocking(false).unwrap();
    socket
        .set_read_timeout(Some(Duration::from_secs(2)))
        .unwrap();
    let mut bytes = Vec::new();
    while !bytes.ends_with(b"\r\n\r\n") {
        let mut byte = [0];
        assert_eq!(socket.read(&mut byte).unwrap(), 1);
        bytes.push(byte[0]);
        assert!(bytes.len() < 64 * 1024);
    }
    let header = String::from_utf8_lossy(&bytes);
    let length = header
        .lines()
        .find_map(|line| {
            line.to_ascii_lowercase()
                .strip_prefix("content-length:")
                .map(|n| n.trim().parse::<usize>().unwrap())
        })
        .unwrap_or(0);
    let mut body = vec![0; length];
    socket.read_exact(&mut body).unwrap();
    bytes.extend(body);
    (socket, bytes)
}

fn timed_transport() -> ReqwestTransport {
    ReqwestTransport {
        client: builder()
            .timeout(Duration::from_millis(100))
            .read_timeout(Duration::from_millis(100))
            .build()
            .unwrap(),
        scoped_client: None,
        runtime: Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap(),
    }
}

#[test]
fn actual_request_deadline_and_future_cancellation_close_the_socket() {
    for cancel in [false, true] {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/pending", listener.local_addr().unwrap());
        let (ready_tx, ready_rx) = mpsc::channel();
        let server = std::thread::spawn(move || {
            let (mut socket, _) = accept_request(&listener);
            ready_tx.send(()).unwrap();
            let mut byte = [0];
            socket.read(&mut byte)
        });
        let transport = if cancel {
            ReqwestTransport::new().unwrap()
        } else {
            timed_transport()
        };
        let runtime = tokio::runtime::Runtime::new().unwrap();
        if cancel {
            assert!(runtime
                .block_on(async {
                    tokio::time::timeout(
                        Duration::from_millis(100),
                        transport.send(HttpRequest::get(url)),
                    )
                    .await
                })
                .is_err());
        } else {
            assert_eq!(
                runtime.block_on(transport.send(HttpRequest::get(url))),
                Err(TransportError::Unreachable)
            );
        }
        ready_rx.recv_timeout(Duration::from_secs(2)).unwrap();
        assert_eq!(
            server.join().unwrap().unwrap(),
            0,
            "a completed deadline/cancel must not leave an orphan HTTP task"
        );
    }
}

#[test]
fn actual_response_limits_and_truncation_are_transport_failures() {
    for response in [
        b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\n12345".as_slice(),
        b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\n12345\r\n0\r\n\r\n".as_slice(),
        b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\nConnection: close\r\n\r\n12".as_slice(),
    ] {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/bounded",listener.local_addr().unwrap());
        let response = response.to_vec();
        let server = std::thread::spawn(move || { let (mut socket, _) = accept_request(&listener); socket.write_all(&response).unwrap(); });
        let transport = ReqwestTransport::new().unwrap();
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let mut request = HttpRequest::get(url);
        request.response_limit = Some(4);
        assert_eq!(runtime.block_on(transport.send(request)),Err(TransportError::Unavailable));
        server.join().unwrap();
    }
}

#[test]
fn actual_post_with_lost_response_is_submitted_once() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}/single", listener.local_addr().unwrap());
    let server = std::thread::spawn(move || {
        let (socket, bytes) = accept_request(&listener);
        assert!(bytes.ends_with(b"synthetic=single"));
        drop(socket);
        let started = std::time::Instant::now();
        while started.elapsed() < Duration::from_millis(200) {
            assert!(
                listener.accept().is_err(),
                "an uncertain POST must never be retransmitted"
            );
            std::thread::sleep(Duration::from_millis(2));
        }
    });
    let transport = ReqwestTransport::new().unwrap();
    let runtime = tokio::runtime::Runtime::new().unwrap();
    assert_eq!(
        runtime.block_on(transport.send(HttpRequest::post_form(url, "synthetic=single"))),
        Err(TransportError::Unavailable)
    );
    server.join().unwrap();
}

#[test]
fn actual_cookie_max_age_starts_at_response_arrival() {
    use crate::auth::session::{RouteMode, Session};
    use crate::foundation::cookie::CookieJar;
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}/short-cookie", listener.local_addr().unwrap());
    let server = std::thread::spawn(move || {
        let (mut socket, _) = accept_request(&listener);
        std::thread::sleep(Duration::from_millis(250));
        socket.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nSet-Cookie: SHORT=synthetic; Max-Age=1; Path=/\r\nConnection: close\r\n\r\nok").unwrap();
    });
    let session = Session::new(ReqwestTransport::new().unwrap());
    session.set_route(RouteMode::Direct);
    let runtime = tokio::runtime::Runtime::new().unwrap();
    runtime
        .block_on(session.send(HttpRequest::get(&url)))
        .unwrap();
    let arrival = CookieJar::now_ms();
    server.join().unwrap();
    assert_eq!(
        session
            .cookie_snapshot()
            .direct
            .header_for(&url, arrival + 900),
        Some("SHORT=synthetic".into()),
        "request latency must not consume a response cookie's Max-Age"
    );
}
