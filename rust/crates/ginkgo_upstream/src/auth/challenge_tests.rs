use super::*;
use crate::foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError};
use std::sync::{Arc, Mutex};

#[derive(Clone)]
struct Transport {
    response: HttpResponse,
    requests: Arc<Mutex<Vec<HttpRequest>>>,
}
impl HttpTransport for Transport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.requests.lock().unwrap().push(request);
        Ok(self.response.clone())
    }
}
fn jpeg() -> HttpResponse {
    let mut response = HttpResponse::new(200, "https://sso.buaa.edu.cn/captcha", "");
    response.bytes = Some(vec![0xff, 0xd8, 0xff, 0xe0, 0xff, 0xd9]);
    response
}
#[tokio::test]
async fn image_uses_fixed_origin_and_encoded_id_with_bound() {
    let transport = Transport {
        response: jpeg(),
        requests: Default::default(),
    };
    let session = Session::new(transport.clone());
    assert_eq!(image(&session, "cap&injected=1").await.unwrap().len(), 6);
    let requests = transport.requests.lock().unwrap();
    assert_eq!(requests.len(), 1);
    assert_eq!(
        requests[0].url,
        "https://sso.buaa.edu.cn/captcha?captchaId=cap%26injected%3D1"
    );
    assert!(requests[0].binary_response);
    assert_eq!(requests[0].response_limit, Some(1024 * 1024));
}
#[tokio::test]
async fn redirects_html_and_oversized_bytes_fail_without_following() {
    for response in [
        HttpResponse::new(302, "https://sso.buaa.edu.cn/captcha", "")
            .with_header("Location", "https://outside.invalid"),
        HttpResponse::new(200, "https://sso.buaa.edu.cn/captcha", "<html>login</html>"),
        {
            let mut response = jpeg();
            response.bytes = Some(vec![0xff; 1024 * 1024 + 1]);
            response
        },
    ] {
        let transport = Transport {
            response,
            requests: Default::default(),
        };
        assert!(image(&Session::new(transport.clone()), "cap")
            .await
            .is_err());
        assert_eq!(transport.requests.lock().unwrap().len(), 1);
    }
}
