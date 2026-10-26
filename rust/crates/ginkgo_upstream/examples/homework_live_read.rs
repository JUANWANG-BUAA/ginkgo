//! Explicit opt-in read-only live acceptance. Credentials arrive on stdin.
use ginkgo_domain::ports::*;
use ginkgo_upstream::{
    adapters::reqwest_transport::ReqwestTransport,
    auth::{session::Session, vault::MemoryVault},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError},
    services::session_service::SchoolClient,
};
use std::io::{self, Read};
struct Trace(ReqwestTransport);
impl HttpTransport for Trace {
    async fn send(&self, r: HttpRequest) -> Result<HttpResponse, TransportError> {
        let path = url::Url::parse(&r.url)
            .ok()
            .map(|u| u.path().to_owned())
            .unwrap_or_default();
        eprintln!("HTTP {:?} {}", r.method, path);
        let result = self.0.send(r).await;
        match &result {
            Ok(v) => eprintln!(
                "HTTP result={} bytes={}",
                v.status,
                v.bytes.as_ref().map(Vec::len).unwrap_or(v.body.len())
            ),
            Err(_) => eprintln!("HTTP transport unavailable"),
        }
        result
    }
}
#[tokio::main(flavor = "current_thread")]
async fn main() {
    if std::env::var("GINKGO_MANUAL_LIVE_NETWORK").as_deref() != Ok("1") {
        eprintln!("explicit live opt-in required");
        std::process::exit(2);
    }
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut parts = input.lines();
    let account = parts.next().unwrap_or("").to_owned();
    let password = parts.next().unwrap_or("").to_owned();
    drop(input);
    let service = SchoolClient::new(
        Session::new(Trace(ReqwestTransport::new().unwrap())),
        MemoryVault::default(),
    );
    if std::env::args().any(|a| a == "--webvpn") {
        service.set_route(RoutePreference::WebVpn);
    }
    let result=tokio::time::timeout(std::time::Duration::from_secs(240),async {
  match service.sign_in(&account,&password,None,false).await {Ok(SessionOutcome::SignedIn{..})=>println!("LOGIN OK"),Ok(_)=>{println!("LOGIN requires user interaction");return;},Err(e)=>{println!("LOGIN FAIL {:?}",e.code);return;}}
  let list=match service.load_homework(true).await{Ok(v)=>v,Err(e)=>{println!("LIST FAIL {:?}",e.code);return;}};
  println!("LIST OK items={} stale={}",list.data.items.len(),list.failure.is_some());
  let submitted_only=std::env::args().any(|a|a=="--submitted");
 let items:Vec<_>=list.data.items.iter().filter(|i|i.course_role.as_deref()==Some("student")).filter(|i|!submitted_only || matches!(i.status,ginkgo_domain::features::homework::HomeworkStatus::Submitted)).take(2).collect();
  println!("STUDENT SAMPLES {}",items.len());
  for (index,item) in items.iter().enumerate(){
   match service.load_homework_detail(&item.id,true).await{Ok(v)=>println!("DETAIL {} OK body={} stale={}",index,v.data.content.is_some(),v.failure.is_some()),Err(e)=>println!("DETAIL {} FAIL {:?}",index,e.code)}
   match service.homework_workspace(&item.id).await {
    Ok(w)=>{println!("FILES {} OK attachments={} methods={:?} count={:?} limit={:?} write_enabled={}",index,w.attachments.len(),w.allowed_methods,w.submitted_count,w.submission_limit,w.can_submit_file);
     println!("SUBMISSION {} count={:?} submitted_files={} text_present={} returned={}",index,w.submitted_count,w.attachments.iter().filter(|a|a.kind=="submitted").count(),w.submitted_text.as_ref().is_some_and(|t|!t.is_empty()),w.returned);
     if let Some(a)=w.attachments.iter().find(|a| if submitted_only {a.kind=="submitted"} else {a.kind=="teacher" || a.kind=="submitted"}){
      println!("DOWNLOAD_KIND {} {}",index,a.kind);
      match service.download_homework_file(&item.id,&a.id).await{Ok(f)=>println!("DOWNLOAD {} OK bytes={} pdf_magic={}",index,f.bytes.len(),f.bytes.starts_with(b"%PDF")),Err(e)=>println!("DOWNLOAD {} FAIL {:?}",index,e.code)}
     }
    },Err(e)=>println!("FILES {} FAIL {:?}",index,e.code)
   }
  }
 }).await;
    if result.is_err() {
        println!("LIVE TIMEOUT");
    }
    service.sign_out().await;
    tokio::task::spawn_blocking(move || drop(service))
        .await
        .unwrap();
    println!("DONE read-only; no upload or submission calls");
}
