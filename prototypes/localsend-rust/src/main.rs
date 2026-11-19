mod contract;
mod files;

use anyhow::{Context, Result, bail};
use bytes::Bytes;
use contract::{Command, MAX_FILES_PER_TRANSFER, VERSION};
use futures_util::{FutureExt, StreamExt};
use localsend::crypto::cert::{fingerprint_from_cert_der, generate_self_signed};
use localsend::discovery::{
    DEFAULT_DISCOVERY_TIMEOUT, DeviceIdentity, DiscoveryConfig, DiscoveryEvent, DiscoveryHandle,
};
use localsend::http::client::ClientError;
use localsend::http::client::v2::LsHttpClientV2;
use localsend::http::dto_v2::{PrepareUploadRequestDtoV2, RegisterDtoV2};
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2, SessionEndReasonV2};
use localsend::http::server::{ServerConfigV2, TlsConfig, start_with_port};
use localsend::http::state::ClientInfo;
use localsend::model::discovery::{DeviceType, PROTOCOL_VERSION_V2, ProtocolType};
use localsend::model::transfer::{FileContent, FileDto, FileMetadata};
use localsend::multicast::{
    DEFAULT_MULTICAST_GROUP, DEFAULT_MULTICAST_GROUP_V6, DEFAULT_PORT, MulticastDevice,
};
use localsend::util::interface::{InterfaceFilter, local_interface_addresses};
use serde_json::{Value, json};
use std::collections::{HashMap, HashSet};
use std::env;
use std::io::{self, Write};
use std::panic::AssertUnwindSafe;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncBufRead, AsyncBufReadExt};
use tokio::sync::{mpsc, oneshot};
use tokio::task::JoinSet;
use tokio_util::sync::CancellationToken;
use tracing::{error, warn};
use uuid::Uuid;

const MAX_JSONL_LINE: usize = 64 * 1024;
const MAX_ACTIVE_TRANSFERS: usize = 2;
const MAX_COMMANDS_PER_PROCESS: usize = 65_536;
const RECEIVE_CONFIRM_TIMEOUT: Duration = Duration::from_secs(60);
const DEFAULT_SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(30);
const FORCED_SHUTDOWN_GRACE: Duration = Duration::from_secs(5);
const PORT: u16 = DEFAULT_PORT;

#[derive(Clone)]
struct Identity {
    alias: String,
    cert_pem: String,
    key_pem: String,
    fingerprint: String,
}

impl Identity {
    fn load_or_generate(state_dir: &Path) -> Result<Self> {
        std::fs::create_dir_all(state_dir)
            .with_context(|| format!("create state directory {}", state_dir.display()))?;
        let path = state_dir.join("identity.pem");
        let existing = match std::fs::symlink_metadata(&path) {
            Ok(_) => {
                ensure_private_identity_file(&path)?;
                Some(
                    std::fs::read_to_string(&path)
                        .with_context(|| format!("read {}", path.display()))?,
                )
            }
            Err(err) if err.kind() == io::ErrorKind::NotFound => None,
            Err(err) => return Err(err).with_context(|| format!("inspect {}", path.display())),
        };
        let (cert_pem, key_pem, fingerprint) = match existing {
            Some(text) => parse_identity(&text)
                .with_context(|| format!("invalid identity file {}", path.display()))?,
            None => {
                let generated = generate_self_signed().context("generate TLS identity")?;
                let contents =
                    format!("{}{}", generated.certificate_pem, generated.private_key_pem);
                write_private_file(&path, contents.as_bytes())
                    .with_context(|| format!("write identity file {}", path.display()))?;
                (
                    generated.certificate_pem,
                    generated.private_key_pem,
                    generated.fingerprint,
                )
            }
        };
        let alias = env::var("HOSTNAME").unwrap_or_else(|_| "VDX Desktop".to_string());
        Ok(Self {
            alias,
            cert_pem,
            key_pem,
            fingerprint,
        })
    }
    fn register(&self) -> RegisterDtoV2 {
        RegisterDtoV2 {
            alias: self.alias.clone(),
            version: PROTOCOL_VERSION_V2.to_string(),
            device_model: Some("Linux".into()),
            device_type: Some(DeviceType::Desktop),
            fingerprint: self.fingerprint.clone(),
            port: PORT,
            protocol: ProtocolType::Https,
            download: false,
        }
    }
    fn multicast_device(&self) -> MulticastDevice {
        MulticastDevice {
            alias: self.alias.clone(),
            version: PROTOCOL_VERSION_V2.to_string(),
            device_model: Some("Linux".into()),
            device_type: Some(DeviceType::Desktop),
            fingerprint: self.fingerprint.clone(),
            port: PORT,
            protocol: ProtocolType::Https,
            download: false,
        }
    }
    fn client_info(&self) -> ClientInfo {
        ClientInfo {
            alias: self.alias.clone(),
            version: PROTOCOL_VERSION_V2.to_string(),
            device_model: Some("Linux".into()),
            device_type: Some(DeviceType::Desktop),
            token: self.fingerprint.clone(),
        }
    }
}

enum ReadLine {
    Line(Vec<u8>),
    TooLong,
    Eof,
}

async fn read_bounded_line<R: AsyncBufRead + Unpin>(reader: &mut R) -> io::Result<ReadLine> {
    let mut line = Vec::new();
    let mut too_long = false;
    loop {
        let available = reader.fill_buf().await?;
        if available.is_empty() {
            return Ok(if line.is_empty() && !too_long {
                ReadLine::Eof
            } else if too_long {
                ReadLine::TooLong
            } else {
                ReadLine::Line(line)
            });
        }
        let newline = available.iter().position(|byte| *byte == b'\n');
        let consumed = newline.map_or(available.len(), |index| index + 1);
        let content_len = newline.unwrap_or(available.len());
        if !too_long {
            if line.len().saturating_add(content_len) > MAX_JSONL_LINE {
                too_long = true;
                line.clear();
            } else {
                line.extend_from_slice(&available[..content_len]);
            }
        }
        reader.consume(consumed);
        if newline.is_some() {
            return Ok(if too_long {
                ReadLine::TooLong
            } else {
                ReadLine::Line(line)
            });
        }
    }
}

fn event(name: &str, fields: Value) -> Value {
    let mut value = serde_json::Map::new();
    value.insert("v".into(), json!(VERSION));
    value.insert("event".into(), json!(name));
    if let Value::Object(fields) = fields {
        value.extend(fields);
    }
    Value::Object(value)
}
async fn emit(tx: &mpsc::Sender<Value>, value: Value) {
    if tx.send(value).await.is_err() {
        error!("stdout event channel closed");
    }
}
async fn emit_error(
    tx: &mpsc::Sender<Value>,
    id: Option<&str>,
    code: &str,
    message: impl ToString,
) {
    emit(
        tx,
        event(
            "error",
            json!({"id":id,"code":code,"message":message.to_string()}),
        ),
    )
    .await;
}
async fn command_result(tx: &mpsc::Sender<Value>, id: &str, fields: Value) {
    let mut result = serde_json::Map::new();
    result.insert("id".into(), json!(id));
    result.insert("ok".into(), json!(true));
    if let Value::Object(fields) = fields {
        result.extend(fields);
    }
    emit(tx, event("command_result", Value::Object(result))).await;
}
fn interface_ips() -> Vec<std::net::Ipv4Addr> {
    local_interface_addresses(&InterfaceFilter::default()).unwrap_or_else(|err| {
        warn!("cannot enumerate LAN interfaces: {err}");
        Vec::new()
    })
}
fn device_json(device: &localsend::discovery::StatefulDevice) -> Value {
    let channel = device.get_best_channel().and_then(|channel| channel.http());
    let (host, port, protocol) = channel
        .map(|http| (http.host.clone(), http.port, http.protocol.as_str()))
        .unwrap_or_else(|| (String::new(), PORT, "https"));
    json!({"fingerprint":device.device.fingerprint,"alias":device.device.alias,"deviceModel":device.device.device_model,
        "deviceType":device.device.device_type,"host":host,"port":port,"protocol":protocol})
}
fn device_json_from_discovered(device: &localsend::discovery::DiscoveredDevice) -> Value {
    let channel = match &device.channel {
        localsend::discovery::DeviceChannel::Http(http) => {
            json!({"host":http.host,"port":http.port,"protocol":http.protocol.as_str()})
        }
    };
    json!({"alias":device.alias,"fingerprint":device.fingerprint,"version":device.version,"deviceModel":device.device_model,
        "deviceType":device.device_type,"channel":channel})
}
fn devices_json(discovery: &DiscoveryHandle) -> Vec<Value> {
    let mut devices: Vec<Value> = discovery.devices().iter().map(device_json).collect();
    devices.sort_by(|a, b| a["fingerprint"].as_str().cmp(&b["fingerprint"].as_str()));
    devices
}
fn default_state_dir() -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            env::var_os("HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."))
                .join(".local/state")
        })
        .join("vdx-localsend-prototype")
}
fn default_download_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join("Downloads/LocalSend-Prototype")
}
fn parse_args() -> Result<(PathBuf, PathBuf)> {
    let mut state_dir = default_state_dir();
    let mut download_dir = default_download_dir();
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--state-dir" => {
                state_dir = PathBuf::from(args.next().context("--state-dir requires a path")?)
            }
            "--download-dir" => {
                download_dir = PathBuf::from(args.next().context("--download-dir requires a path")?)
            }
            "--help" | "-h" => {
                eprintln!(
                    "vdx-localsend-prototype [--state-dir PATH] [--download-dir PATH]\nJSONL v1 commands are read from stdin; diagnostics use stderr."
                );
                std::process::exit(0);
            }
            other => bail!("unknown argument: {other}"),
        }
    }
    Ok((state_dir, download_dir))
}
fn write_private_file(path: &Path, bytes: &[u8]) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(path)?;
        file.write_all(bytes)
    }
    #[cfg(not(unix))]
    {
        std::fs::write(path, bytes)
    }
}

fn ensure_private_identity_file(path: &Path) -> Result<()> {
    let metadata = std::fs::symlink_metadata(path)
        .with_context(|| format!("inspect identity file {}", path.display()))?;
    if !metadata.file_type().is_file() {
        bail!("identity path must be a regular, non-symlink file");
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::{MetadataExt, PermissionsExt};
        if metadata.mode() & 0o077 != 0 {
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).with_context(
                || format!("restrict identity file permissions {}", path.display()),
            )?;
        }
    }
    Ok(())
}
fn parse_identity(text: &str) -> Result<(String, String, String)> {
    let blocks = pem::parse_many(text)?;
    let cert = blocks
        .iter()
        .find(|block| block.tag() == "CERTIFICATE")
        .context("missing certificate")?;
    let key = blocks
        .iter()
        .find(|block| block.tag().ends_with("PRIVATE KEY"))
        .context("missing private key")?;
    Ok((
        pem::encode(cert),
        pem::encode(key),
        fingerprint_from_cert_der(cert.contents()),
    ))
}

struct PendingReceive {
    transfer_id: String,
    info: RegisterDtoV2,
    files: HashMap<String, FileDto>,
    decision_tx: oneshot::Sender<PrepareUploadDecisionV2>,
    deadline: tokio::time::Instant,
}
struct ReceiveSession {
    transfer_id: String,
    command_id: String,
    alias: String,
    fingerprint: String,
    selected: HashMap<String, FileDto>,
    active_files: HashSet<String>,
    outcomes: HashMap<String, Value>,
    cancellation: CancellationToken,
    file_semaphore: Arc<tokio::sync::Semaphore>,
    progress_bytes: Arc<std::sync::atomic::AtomicU64>,
    total_bytes: u64,
    transferred_bytes: u64,
    remote_ended: Option<SessionEndReasonV2>,
    cancel_requested: bool,
}
struct ActiveSend {
    command_id: String,
    cancellation: CancellationToken,
}
struct SendOutcome {
    transfer_id: String,
    command_id: String,
    state: &'static str,
    files: Vec<Value>,
    error: Option<(String, String)>,
}
enum TaskEvent {
    Send(SendOutcome),
    ReceivedFile {
        session_id: String,
        file_id: String,
        result: Result<(PathBuf, u64), String>,
    },
}

fn failed_send(
    transfer_id: &str,
    command_id: &str,
    code: &str,
    message: String,
    files: Vec<Value>,
) -> SendOutcome {
    SendOutcome {
        transfer_id: transfer_id.into(),
        command_id: command_id.into(),
        state: "failed",
        files,
        error: Some((code.into(), message)),
    }
}

fn cancelled_send(
    transfer_id: &str,
    command_id: &str,
    sources: &[(PathBuf, String, u64, String)],
    completed: Vec<Value>,
) -> SendOutcome {
    let mut known: HashMap<String, Value> = completed
        .into_iter()
        .filter_map(|file| {
            let id = file["fileId"].as_str()?.to_string();
            Some((id, file))
        })
        .collect();
    let files = sources
        .iter()
        .map(|(_, name, size, file_id)| {
            known.remove(file_id).unwrap_or_else(|| {
                json!({"fileId":file_id,"fileName":name,"state":"cancelled","bytes":size,
                    "error":{"code":"cancelled","message":"transfer session was cancelled"}})
            })
        })
        .collect();
    SendOutcome {
        transfer_id: transfer_id.into(),
        command_id: command_id.into(),
        state: "cancelled",
        files,
        error: None,
    }
}

fn report_send_progress(
    output: &mpsc::Sender<Value>,
    command_id: &str,
    transfer_id: &str,
    file_id: &str,
    file_name: &str,
    file_bytes: u64,
    file_total: u64,
    transferred: u64,
    total: u64,
) {
    let _ = output.try_send(event(
        "transfer_progress",
        json!({"id":command_id,"transferId":transfer_id,
        "fileId":file_id,"fileName":file_name,"fileBytes":file_bytes,"fileTotal":file_total,
        "transferredBytes":transferred,"totalBytes":total}),
    ));
}

async fn send_batch(
    transfer_id: String,
    command_id: String,
    fingerprint: String,
    paths: Vec<String>,
    device: localsend::discovery::StatefulDevice,
    identity: Arc<Identity>,
    output: mpsc::Sender<Value>,
    cancellation: CancellationToken,
) -> SendOutcome {
    let mut sources = Vec::with_capacity(paths.len());
    let mut file_results = Vec::with_capacity(paths.len());
    let mut total_bytes = 0_u64;
    for source in paths {
        let canonical = match std::fs::canonicalize(&source) {
            Ok(path) => path,
            Err(err) => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "source_unavailable",
                    format!("cannot resolve source: {err}"),
                    file_results,
                );
            }
        };
        let metadata = match std::fs::metadata(&canonical) {
            Ok(metadata) if metadata.is_file() => metadata,
            Ok(_) => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "invalid_source",
                    "source path is not a regular file".into(),
                    file_results,
                );
            }
            Err(err) => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "source_unavailable",
                    format!("cannot inspect source: {err}"),
                    file_results,
                );
            }
        };
        let name = match canonical.file_name().and_then(|name| name.to_str()) {
            Some(name) => match files::safe_basename(name) {
                Ok(name) => name.to_string(),
                Err(message) => {
                    return failed_send(
                        &transfer_id,
                        &command_id,
                        "invalid_source",
                        message,
                        file_results,
                    );
                }
            },
            None => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "invalid_source",
                    "source filename is not valid UTF-8".into(),
                    file_results,
                );
            }
        };
        total_bytes = total_bytes.saturating_add(metadata.len());
        sources.push((canonical, name, metadata.len(), Uuid::new_v4().to_string()));
    }
    let Some(channel) = device
        .get_best_channel()
        .and_then(|channel| channel.http())
        .cloned()
    else {
        return failed_send(
            &transfer_id,
            &command_id,
            "device_unavailable",
            "selected device has no HTTP channel".into(),
            file_results,
        );
    };
    let expected = (channel.protocol == ProtocolType::Https).then_some(fingerprint.clone());
    let client =
        match LsHttpClientV2::try_new(&identity.key_pem, &identity.cert_pem, expected, None) {
            Ok(client) => client,
            Err(err) => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "tls_error",
                    format!("cannot create pinned LocalSend client: {err}"),
                    file_results,
                );
            }
        };
    let mut dto_files = HashMap::with_capacity(sources.len());
    for (path, name, declared_size, file_id) in &sources {
        let (size, sha256) = match files::hash_file(path, &cancellation).await {
            Ok(value) => value,
            Err(_err) if cancellation.is_cancelled() => {
                return cancelled_send(&transfer_id, &command_id, &sources, file_results);
            }
            Err(err) => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "source_read_error",
                    format!("cannot hash {name}: {err}"),
                    file_results,
                );
            }
        };
        if size != *declared_size {
            return failed_send(
                &transfer_id,
                &command_id,
                "source_changed",
                format!("{name} changed while preparing transfer"),
                file_results,
            );
        }
        dto_files.insert(
            file_id.clone(),
            FileDto {
                id: file_id.clone(),
                file_name: name.clone(),
                size,
                file_type: mime_guess::from_path(path)
                    .first_or_octet_stream()
                    .to_string(),
                sha256: Some(sha256),
                preview: None,
                metadata: FileMetadata::from_path(path),
            },
        );
    }
    let prepared = tokio::select! {
        _=cancellation.cancelled()=>return cancelled_send(&transfer_id,&command_id,&sources,file_results),
        result=client.prepare_upload(channel.protocol,&channel.host,channel.port,None,
            PrepareUploadRequestDtoV2{info:identity.register(),files:dto_files},None,cancellation.clone())=>result,
    };
    let response = match prepared {
        Ok(result) => match result.response {
            Some(response) => response,
            None => {
                return failed_send(
                    &transfer_id,
                    &command_id,
                    "protocol_error",
                    "peer reported no file transfer for a file batch".into(),
                    file_results,
                );
            }
        },
        Err(ClientError::StatusCode(err)) => {
            return failed_send(
                &transfer_id,
                &command_id,
                "protocol_error",
                format!(
                    "prepare-upload HTTP {}: {}",
                    err.status,
                    err.message.unwrap_or_default()
                ),
                file_results,
            );
        }
        Err(_err) if cancellation.is_cancelled() => {
            return cancelled_send(&transfer_id, &command_id, &sources, file_results);
        }
        Err(err) => {
            return failed_send(
                &transfer_id,
                &command_id,
                "network_error",
                format!("prepare-upload failed: {err}"),
                file_results,
            );
        }
    };
    let mut total_transferred = 0_u64;
    for (index, (path, name, size, file_id)) in sources.iter().enumerate() {
        if cancellation.is_cancelled() {
            let _ = tokio::time::timeout(
                Duration::from_secs(3),
                client.cancel(
                    channel.protocol,
                    &channel.host,
                    channel.port,
                    &response.session_id,
                ),
            )
            .await;
            return cancelled_send(&transfer_id, &command_id, &sources, file_results);
        }
        let Some(token) = response.files.get(file_id) else {
            file_results.push(
                json!({"fileId":file_id,"fileName":name,"index":index,"state":"failed",
                "error":{"code":"rejected","message":"receiver did not accept this file"}}),
            );
            continue;
        };
        let content = FileContent::Path(path.clone());
        let output_progress = output.clone();
        let command_progress = command_id.clone();
        let transfer_progress = transfer_id.clone();
        let file_id_progress = file_id.clone();
        let name_progress = name.clone();
        let file_total = *size;
        let prior = total_transferred;
        let total = total_bytes;
        let mut file_sent = 0_u64;
        let stream = tokio_stream::wrappers::ReceiverStream::new(content.into_receiver()).map(
            move |chunk: Bytes| {
                file_sent = file_sent.saturating_add(chunk.len() as u64);
                report_send_progress(
                    &output_progress,
                    &command_progress,
                    &transfer_progress,
                    &file_id_progress,
                    &name_progress,
                    file_sent,
                    file_total,
                    prior.saturating_add(file_sent),
                    total,
                );
                Ok::<Bytes, anyhow::Error>(chunk)
            },
        );
        let body = localsend::reqwest::Body::wrap_stream(stream);
        let uploading = client.upload(
            channel.protocol,
            &channel.host,
            channel.port,
            None,
            &response.session_id,
            file_id,
            token,
            body,
            cancellation.clone(),
        );
        let result = tokio::select! {
            result=uploading=>result,
            _=cancellation.cancelled()=>{
                let _=tokio::time::timeout(Duration::from_secs(3),client.cancel(channel.protocol,&channel.host,channel.port,&response.session_id)).await;
                return cancelled_send(&transfer_id,&command_id,&sources,file_results);
            }
        };
        match result{
            Ok(())=>{
                total_transferred=total_transferred.saturating_add(*size);
                let file=json!({"fileId":file_id,"fileName":name,"index":index,"state":"completed","bytes":size});
                file_results.push(file.clone());
                emit(&output,event("file_completed",json!({"id":command_id,"transferId":transfer_id,"file":file,
                    "transferredBytes":total_transferred,"totalBytes":total_bytes}))).await;
            }
            Err(ClientError::StatusCode(err))=>file_results.push(json!({"fileId":file_id,"fileName":name,"index":index,"state":"failed",
                "error":{"code":"protocol_error","message":format!("upload HTTP {}: {}",err.status,err.message.unwrap_or_default())}})),
            Err(_err) if cancellation.is_cancelled()=>return cancelled_send(&transfer_id,&command_id,&sources,file_results),
            Err(err)=>file_results.push(json!({"fileId":file_id,"fileName":name,"index":index,"state":"failed",
                "error":{"code":"network_error","message":format!("upload failed: {err}")}})),
        }
    }
    let failed = file_results.iter().any(|file| file["state"] == "failed");
    SendOutcome {
        transfer_id,
        command_id,
        state: if failed { "failed" } else { "completed" },
        files: file_results,
        error: None,
    }
}

fn finished_event(outcome: SendOutcome) -> Value {
    let error = outcome
        .error
        .map(|(code, message)| json!({"code":code,"message":message}));
    event(
        "transfer_finished",
        json!({"id":outcome.command_id,"transferId":outcome.transfer_id,
        "state":outcome.state,"files":outcome.files,"error":error}),
    )
}

fn receive_request_expired(deadline: tokio::time::Instant, now: tokio::time::Instant) -> bool {
    deadline <= now
}

fn graceful_shutdown_expired(
    forced: bool,
    deadline: Option<tokio::time::Instant>,
    now: tokio::time::Instant,
) -> bool {
    !forced && deadline.is_some_and(|deadline| now >= deadline)
}

fn remember_command_id(id: &str, ids: &mut HashSet<String>) -> Result<(), &'static str> {
    if ids.contains(id) {
        return Err("duplicate_command_id");
    }
    if ids.len() >= MAX_COMMANDS_PER_PROCESS {
        return Err("command_limit");
    }
    ids.insert(id.to_string());
    Ok(())
}

async fn handle_server_event(
    event_value: ServerEventV2,
    identity: &Identity,
    download_dir: &files::DownloadRoot,
    discovery: &Arc<DiscoveryHandle>,
    output: &mpsc::Sender<Value>,
    pending: &mut HashMap<String, PendingReceive>,
    receives: &mut HashMap<String, ReceiveSession>,
    tasks: &mut JoinSet<TaskEvent>,
    stopping: bool,
    active_limit_reached: bool,
) {
    use std::sync::atomic::Ordering;
    match event_value {
        ServerEventV2::Register { ip, info } => {
            let device = localsend::discovery::DiscoveredDevice {
                alias: info.alias,
                version: info.version,
                device_model: info.device_model,
                device_type: info.device_type,
                fingerprint: info.fingerprint,
                channel: localsend::discovery::DeviceChannel::Http(
                    localsend::discovery::HttpChannel {
                        host: ip.to_string(),
                        port: info.port,
                        protocol: info.protocol,
                    },
                ),
                download: info.download,
            };
            if device.fingerprint != identity.fingerprint {
                discovery.add_device(device.clone()).await;
            }
            emit(
                output,
                event(
                    "peer_registered",
                    json!({"id":Value::Null,"alias":device.alias,
                "fingerprint":device.fingerprint,"host":ip.to_string()}),
                ),
            )
            .await;
        }
        ServerEventV2::PrepareUpload {
            session_id,
            ip,
            info,
            cert_fingerprint,
            files,
            decision_tx,
        } => {
            if stopping {
                let _ = decision_tx.send(PrepareUploadDecisionV2::Decline);
                emit(
                    output,
                    event(
                        "incoming_rejected",
                        json!({"id":Value::Null,"sessionId":session_id,"reason":"shutting_down"}),
                    ),
                )
                .await;
                return;
            }
            if cert_fingerprint.as_deref().map(str::to_ascii_uppercase)
                != Some(info.fingerprint.to_ascii_uppercase())
            {
                let _ = decision_tx.send(PrepareUploadDecisionV2::Decline);
                emit_error(
                    output,
                    None,
                    "fingerprint_mismatch",
                    "verified client certificate does not match LocalSend fingerprint",
                )
                .await;
                return;
            }
            if active_limit_reached
                || !pending.is_empty()
                || !receives.is_empty()
                || pending.contains_key(&session_id)
                || files.is_empty()
                || files.len() > MAX_FILES_PER_TRANSFER
            {
                let _ = decision_tx.send(PrepareUploadDecisionV2::Decline);
                emit(
                    output,
                    event(
                        "incoming_rejected",
                        json!({"id":Value::Null,"sessionId":session_id,"reason":"busy_or_invalid"}),
                    ),
                )
                .await;
                return;
            }
            let mut offered:Vec<Value>=files.iter().map(|(id,file)|json!({"fileId":id,"fileName":file.file_name,"size":file.size,"fileType":file.file_type})).collect();
            offered.sort_by(|a, b| a["fileId"].as_str().cmp(&b["fileId"].as_str()));
            let transfer_id = Uuid::new_v4().to_string();
            pending.insert(
                session_id.clone(),
                PendingReceive {
                    transfer_id: transfer_id.clone(),
                    info: info.clone(),
                    files,
                    decision_tx,
                    deadline: tokio::time::Instant::now() + RECEIVE_CONFIRM_TIMEOUT,
                },
            );
            emit(output,event("incoming",json!({"id":Value::Null,"sessionId":session_id,"transferId":transfer_id,
                "alias":info.alias,"fingerprint":info.fingerprint,"host":ip.to_string(),"files":offered,
                "confirmTimeoutSeconds":RECEIVE_CONFIRM_TIMEOUT.as_secs()}))).await;
        }
        ServerEventV2::FileUpload {
            session_id,
            file_id,
            file,
            target_tx,
        } => {
            let Some(receive) = receives.get_mut(&session_id) else {
                drop(target_tx);
                emit_error(
                    output,
                    None,
                    "unexpected_upload",
                    "upload arrived without an accepted session",
                )
                .await;
                return;
            };
            if !receive.selected.contains_key(&file_id)
                || !receive.active_files.insert(file_id.clone())
            {
                drop(target_tx);
                emit_error(
                    output,
                    Some(&receive.command_id),
                    "unexpected_file",
                    "file is unselected or duplicated",
                )
                .await;
                return;
            }
            let (binary_tx, binary_rx) = mpsc::channel::<Bytes>(1);
            let (result_tx, result_rx) = oneshot::channel();
            if target_tx
                .send(FileUploadTarget::Stream {
                    binary_tx,
                    result_rx,
                })
                .is_err()
            {
                receive.active_files.remove(&file_id);
                emit_error(
                    output,
                    Some(&receive.command_id),
                    "protocol_error",
                    "LocalSend core closed the upload target",
                )
                .await;
                return;
            }
            let root = download_dir.clone();
            let cancel = receive.cancellation.clone();
            let file_semaphore = receive.file_semaphore.clone();
            let transfer_id = receive.transfer_id.clone();
            let command_id = receive.command_id.clone();
            let total = receive.total_bytes;
            let aggregate = receive.progress_bytes.clone();
            let file_name = file.file_name.clone();
            let out = output.clone();
            let session_for_task = session_id.clone();
            let file_id_for_task = file_id.clone();
            tasks.spawn(async move{
                let operation=async{
                    let _permit=tokio::select!{
                        permit=file_semaphore.acquire_owned()=>permit.map_err(|_|"receive semaphore closed".to_string())?,
                        _=cancel.cancelled()=>return Err("transfer cancelled".to_string()),
                    };
                    let mut receiver=binary_rx;let mut last=0_u64;
                    files::receive_stream(&root,&file,&mut receiver,&cancel,|received|{
                        if received.saturating_sub(last)>=256*1024||received==file.size{
                            let delta=received.saturating_sub(last);last=received;
                            let transferred=aggregate.fetch_add(delta,Ordering::Relaxed).saturating_add(delta);
                            let _=out.try_send(event("transfer_progress",json!({"id":command_id,"sessionId":session_for_task,
                                "transferId":transfer_id,"fileId":file_id_for_task,"fileName":file_name,
                                "fileBytes":received,"fileTotal":file.size,"transferredBytes":transferred,"totalBytes":total})));
                        }
                    }).await
                };
                let result=AssertUnwindSafe(operation).catch_unwind().await.unwrap_or_else(|_|Err("receive task panicked".into()));
                let core_result=result.as_ref().map(|_|()).map_err(Clone::clone);
                let _=result_tx.send(core_result);
                TaskEvent::ReceivedFile{session_id,file_id,result}
            });
        }
        ServerEventV2::SessionEnd { session_id, reason } => {
            if let Some(receive) = receives.get_mut(&session_id) {
                receive.remote_ended = Some(reason);
            }
            let _ = finalize_receive_if_ready(&session_id, receives, output).await;
        }
        ServerEventV2::PrepareUploadAborted { session_id } => {
            if let Some(request) = pending.remove(&session_id) {
                emit(output,event("incoming_expired",json!({"id":Value::Null,"sessionId":session_id,"transferId":request.transfer_id}))).await;
            }
        }
        ServerEventV2::CancelReceived { session_id, .. } => {
            if let Some(receive) = receives.get_mut(&session_id) {
                receive.cancel_requested = true;
                receive.cancellation.cancel();
            }
            emit(
                output,
                event(
                    "remote_cancel",
                    json!({"id":Value::Null,"sessionId":session_id}),
                ),
            )
            .await;
            let _ = finalize_receive_if_ready(&session_id, receives, output).await;
        }
        ServerEventV2::ListenerFailed { error } => {
            emit_error(output, None, "listener_failed", error).await
        }
    }
}

async fn finalize_receive_if_ready(
    session_id: &str,
    receives: &mut HashMap<String, ReceiveSession>,
    output: &mpsc::Sender<Value>,
) -> bool {
    let ready = receives.get(session_id).is_some_and(|r| {
        (r.remote_ended.is_some() || r.cancel_requested) && r.active_files.is_empty()
    });
    if !ready {
        return false;
    }
    let receive = receives.remove(session_id).expect("ready receive exists");
    let has_failed = receive
        .outcomes
        .values()
        .any(|file| file["state"] == "failed");
    let state = if receive.cancel_requested
        || receive.remote_ended == Some(SessionEndReasonV2::Cancelled)
    {
        "cancelled"
    } else if has_failed || receive.outcomes.len() < receive.selected.len() {
        "failed"
    } else {
        "completed"
    };
    let mut selected_ids: Vec<String> = receive.selected.keys().cloned().collect();
    selected_ids.sort();
    let outcomes:Vec<Value>=selected_ids.iter().map(|id|receive.outcomes.get(id).cloned().unwrap_or_else(||json!({
        "fileId":id,"state":if state=="cancelled"{"cancelled"}else{"failed"},
        "error":{"code":if state=="cancelled"{"cancelled"}else{"incomplete_session"},
        "message":if state=="cancelled"{"transfer session was cancelled"}else{"peer ended before file arrival"}}}))).collect();
    emit(
        output,
        event(
            "transfer_finished",
            json!({"id":receive.command_id,"sessionId":session_id,"transferId":receive.transfer_id,
        "state":state,"files":outcomes,"alias":receive.alias,"fingerprint":receive.fingerprint,
        "totalBytes":receive.total_bytes,"transferredBytes":receive.transferred_bytes}),
        ),
    )
    .await;
    true
}

async fn main_loop() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_writer(std::io::stderr)
        .init();
    let (state_dir, download_path) = parse_args()?;
    let download_dir = files::prepare_download_dir(&download_path)?;
    let identity = Arc::new(Identity::load_or_generate(&state_dir)?);
    let (server_tx, mut server_rx) = mpsc::channel::<ServerEventV2>(32);
    let (server_stop_tx, server_stop_rx) = oneshot::channel();
    let server = Arc::new(
        start_with_port(
            PORT,
            Some(TlsConfig {
                cert: identity.cert_pem.clone(),
                private_key: identity.key_pem.clone(),
            }),
            identity.client_info(),
            None,
            Some(ServerConfigV2 {
                pin: None,
                verify_checksums: true,
                event_tx: server_tx,
            }),
            None,
            server_stop_rx,
        )
        .await
        .context("start official LocalSend HTTP/TLS server")?,
    );
    // Bind LocalSend's fixed port before cleaning leftovers. A second helper
    // instance then fails startup without deleting another process's .part files.
    files::cleanup_stale_parts(download_dir.display_path())
        .context("clean stale LocalSend partial files")?;
    let (discovery_tx, mut discovery_rx) = mpsc::channel::<DiscoveryEvent>(64);
    let (discovery_stop_tx, discovery_stop_rx) = oneshot::channel();
    let discovery = Arc::new(
        localsend::discovery::start(
            DiscoveryConfig {
                group: DEFAULT_MULTICAST_GROUP,
                group_v6: Some(DEFAULT_MULTICAST_GROUP_V6),
                port: PORT,
                interface_filter: InterfaceFilter::default(),
                device: identity.multicast_device(),
                identity: DeviceIdentity {
                    cert_pem: identity.cert_pem.clone(),
                    private_key_pem: identity.key_pem.clone(),
                },
                timeout: DEFAULT_DISCOVERY_TIMEOUT,
                event_tx: Some(discovery_tx),
            },
            discovery_stop_rx,
        )
        .await,
    );
    if let Some(err) = discovery.multicast_error() {
        warn!("multicast discovery unavailable: {err:#}");
    }

    let (output_tx, mut output_rx) = mpsc::channel::<Value>(256);
    let mut pending = HashMap::<String, PendingReceive>::new();
    let mut receives = HashMap::<String, ReceiveSession>::new();
    let mut sends = HashMap::<String, ActiveSend>::new();
    let mut tasks = JoinSet::<TaskEvent>::new();
    let mut discovery_tasks = JoinSet::<()>::new();
    let mut stdin = tokio::io::BufReader::new(tokio::io::stdin());
    let mut tick = tokio::time::interval(Duration::from_millis(500));
    let mut command_ids = HashSet::new();
    let mut last_devices = HashMap::<String, Value>::new();
    let mut stopping = false;
    let mut forced = false;
    let mut server_stopped = false;
    let mut shutdown_deadline: Option<tokio::time::Instant> = None;
    let mut force_deadline: Option<tokio::time::Instant> = None;
    let mut server_stop_tx = Some(server_stop_tx);
    let mut discovery_stop_tx = Some(discovery_stop_tx);
    emit(&output_tx,event("ready",json!({"port":PORT,"alias":identity.alias,"fingerprint":identity.fingerprint,
        "downloadDir":download_dir.display_path().display().to_string(),"maxActiveTransfers":MAX_ACTIVE_TRANSFERS,"maxFilesPerTransfer":MAX_FILES_PER_TRANSFER}))).await;
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    let mut interrupt = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::interrupt())?;

    loop {
        // The helper cannot pause the core listener independently; while draining it declines new sessions.
        if stopping && receives.is_empty() && pending.is_empty() && !server_stopped {
            if let Some(stop) = server_stop_tx.take() {
                let _ = stop.send(());
            }
            let result = tokio::time::timeout(Duration::from_secs(3), server.wait_stopped()).await;
            if result.is_err() {
                warn!("LocalSend server did not stop within 3 seconds");
            }
            server_stopped = true;
        }
        if stopping
            && server_stopped
            && sends.is_empty()
            && receives.is_empty()
            && tasks.is_empty()
            && discovery_tasks.is_empty()
        {
            break;
        }
        tokio::select! {
            line=read_bounded_line(&mut stdin),if !stopping=>{match line?{
                ReadLine::Eof=>{
                    stopping=true;forced=true;shutdown_deadline=Some(tokio::time::Instant::now());
                    force_deadline=Some(tokio::time::Instant::now()+FORCED_SHUTDOWN_GRACE);
                    if let Some(stop)=discovery_stop_tx.take(){let _=stop.send(());}
                    for(_,request)in pending.drain(){let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);}
                    for send in sends.values(){send.cancellation.cancel();}
                    for(session,receive)in receives.iter_mut(){receive.cancel_requested=true;receive.cancellation.cancel();let _=server.cancel_v2_session(session).await;}
                }
                ReadLine::TooLong=>emit_error(&output_tx,None,"message_too_large","JSONL command exceeds 64 KiB").await,
                ReadLine::Line(line)=>{
                    if line.iter().all(u8::is_ascii_whitespace){continue;}
                    let raw:Value=match serde_json::from_slice(&line){Ok(value)=>value,Err(err)=>{emit_error(&output_tx,None,"invalid_json",format!("invalid JSON: {err}")).await;continue;}};
                    let supplied_id=raw.get("id").and_then(Value::as_str).map(str::to_string);
                    let command=match serde_json::from_value::<Command>(raw){Ok(command)=>command,Err(err)=>{emit_error(&output_tx,supplied_id.as_deref(),"invalid_command",err.to_string()).await;continue;}};
                    if let Err(message)=command.validate(){emit_error(&output_tx,Some(command.id()),"invalid_command",message).await;continue;}
                    let cid=command.id().to_string();
                    if let Err(code)=remember_command_id(&cid,&mut command_ids){
                        let message=if code=="duplicate_command_id"{"command id was already used"}else{"restart helper after 65536 unique commands"};
                        emit_error(&output_tx,Some(&cid),code,message).await;continue;
                    }
                    match command{
                        Command::Discover{id}=>{
                            if discovery_tasks.len()>=2{emit_error(&output_tx,Some(&id),"busy","too many discovery scans are already running").await;continue;}
                            command_result(&output_tx,&id,Value::Null).await;
                            let discovery=discovery.clone();let output=output_tx.clone();
                            discovery_tasks.spawn(async move{
                                match discovery.discover_staged(Vec::new(),interface_ips(),PORT,ProtocolType::Https,Duration::from_millis(700)).await{
                                    Ok(())=>emit(&output,event("discovery_complete",json!({"id":id,"devices":devices_json(&discovery)}))).await,
                                    Err(err)=>emit_error(&output,Some(&id),"discovery_failed",format!("LocalSend discovery failed: {err}")).await,
                                }
                            });
                        }
                        Command::Devices{id}=>command_result(&output_tx,&id,json!({"devices":devices_json(&discovery)})).await,
                        Command::Send{id,fingerprint,paths}=>{
                            if sends.len()+receives.len()+pending.len()>=MAX_ACTIVE_TRANSFERS{emit_error(&output_tx,Some(&id),"busy","maximum active transfer count reached").await;continue;}
                            let Some(device)=discovery.device_by_fingerprint(&fingerprint)else{emit_error(&output_tx,Some(&id),"device_not_found","fingerprint is not in the discovery store").await;continue;};
                            let transfer_id=Uuid::new_v4().to_string();let cancellation=CancellationToken::new();
                            sends.insert(transfer_id.clone(),ActiveSend{command_id:id.clone(),cancellation:cancellation.clone()});
                            command_result(&output_tx,&id,json!({"transferId":transfer_id})).await;
                            emit(&output_tx,event("transfer_started",json!({"id":id,"transferId":transfer_id,"direction":"send","totalFiles":paths.len(),"state":"active"}))).await;
                            let output=output_tx.clone();let identity=identity.clone();
                            let task_transfer=transfer_id.clone();let task_command=id.clone();
                            tasks.spawn(async move{
                                let result=AssertUnwindSafe(send_batch(transfer_id,id,fingerprint,paths,device,identity,output,cancellation)).catch_unwind().await;
                                let outcome=result.unwrap_or_else(|_|SendOutcome{transfer_id:task_transfer,command_id:task_command,
                                    state:"failed",files:Vec::new(),error:Some(("internal_error".into(),"send task panicked".into()))});
                                TaskEvent::Send(outcome)
                            });
                        }
                        Command::Accept{id,session_id,file_ids}=>{
                            let Some(request)=pending.remove(&session_id)else{emit_error(&output_tx,Some(&id),"session_expired","incoming request is no longer pending").await;continue;};
                            let requested:HashSet<String>=file_ids.iter().cloned().collect();
                            if requested.len()!=file_ids.len()||requested.iter().any(|file_id|!request.files.contains_key(file_id)){
                                let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);
                                emit_error(&output_tx,Some(&id),"invalid_file_selection","fileIds must be a unique subset of offered files").await;continue;
                            }
                            let selected:HashMap<String,FileDto>=request.files.into_iter().filter(|(file_id,_)|requested.contains(file_id)).collect();
                            if let Some(file)=selected.values().find(|file|files::safe_basename(&file.file_name).is_err()){
                                let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);
                                emit_error(&output_tx,Some(&id),"unsafe_filename",format!("unsafe incoming filename: {}",file.file_name)).await;continue;
                            }
                            let total_bytes=selected.values().fold(0_u64,|sum,file|sum.saturating_add(file.size));
                            let accept_ids=selected.keys().cloned().collect();let transfer_id=request.transfer_id.clone();
                            let alias=request.info.alias.clone();let fingerprint=request.info.fingerprint.clone();
                            receives.insert(session_id.clone(),ReceiveSession{transfer_id:transfer_id.clone(),command_id:id.clone(),alias,fingerprint,
                                selected,active_files:HashSet::new(),outcomes:HashMap::new(),cancellation:CancellationToken::new(),
                                file_semaphore:Arc::new(tokio::sync::Semaphore::new(2)),
                                progress_bytes:Arc::new(std::sync::atomic::AtomicU64::new(0)),total_bytes,transferred_bytes:0,
                                remote_ended:None,cancel_requested:false});
                            let _=request.decision_tx.send(PrepareUploadDecisionV2::Accept(accept_ids));
                            command_result(&output_tx,&id,json!({"transferId":transfer_id,"sessionId":session_id})).await;
                            emit(&output_tx,event("transfer_started",json!({"id":id,"sessionId":session_id,"transferId":transfer_id,
                                "direction":"receive","totalFiles":file_ids.len(),"totalBytes":total_bytes,"state":"active"}))).await;
                        }
                        Command::Reject{id,session_id}=>match pending.remove(&session_id){
                            Some(request)=>{let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);command_result(&output_tx,&id,json!({"sessionId":session_id,"accepted":false})).await;}
                            None=>emit_error(&output_tx,Some(&id),"session_expired","incoming request is no longer pending").await,
                        },
                        Command::Cancel{id,transfer_id}=>{
                            if let Some(send)=sends.get(&transfer_id){send.cancellation.cancel();command_result(&output_tx,&id,json!({"transferId":transfer_id,"requested":true})).await;}
                            else if let Some((session,receive))=receives.iter_mut().find(|(_,receive)|receive.transfer_id==transfer_id){
                                receive.cancel_requested=true;receive.cancellation.cancel();let session=session.clone();let _=server.cancel_v2_session(&session).await;
                                command_result(&output_tx,&id,json!({"transferId":transfer_id,"sessionId":session,"requested":true})).await;
                                let _=finalize_receive_if_ready(&session,&mut receives,&output_tx).await;
                            }else{emit_error(&output_tx,Some(&id),"transfer_not_active","transfer is no longer active").await;}
                        }
                        Command::Status{id}=>{
                            let mut active:Vec<Value>=sends.iter().map(|(transfer_id,send)|json!({"transferId":transfer_id,"id":send.command_id,"direction":"send","state":"active"})).collect();
                            active.extend(receives.iter().map(|(session,receive)|json!({"transferId":receive.transfer_id,"id":receive.command_id,
                                "sessionId":session,"direction":"receive","state":"active"})));
                            command_result(&output_tx,&id,json!({"state":if stopping{"stopping"}else{"ready"},"devices":devices_json(&discovery),
                                "pendingIncoming":pending.len(),"activeTransfers":active})).await;
                        }
                        Command::Shutdown{id,force,timeout_ms}=>{
                            command_result(&output_tx,&id,json!({"state":"stopping","forced":force})).await;
                            stopping=true;forced=force;
                            shutdown_deadline=Some(tokio::time::Instant::now()+Duration::from_millis(timeout_ms.unwrap_or(DEFAULT_SHUTDOWN_TIMEOUT.as_millis() as u64)));
                            if let Some(stop)=discovery_stop_tx.take(){let _=stop.send(());}
                            for(session,request)in pending.drain(){let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);
                                emit(&output_tx,event("incoming_rejected",json!({"id":Value::Null,"sessionId":session,"reason":"shutting_down"}))).await;}
                            if forced{
                                for send in sends.values(){send.cancellation.cancel();}
                                for(session,receive)in receives.iter_mut(){receive.cancel_requested=true;receive.cancellation.cancel();let _=server.cancel_v2_session(session).await;}
                                force_deadline=Some(tokio::time::Instant::now()+FORCED_SHUTDOWN_GRACE);
                            }
                        }
                    }
                }
            }},
            Some(server_event)=server_rx.recv()=>{
                let active_limit_reached=sends.len()+receives.len()+pending.len()>=MAX_ACTIVE_TRANSFERS;
                handle_server_event(server_event,&identity,&download_dir,&discovery,&output_tx,&mut pending,&mut receives,&mut tasks,stopping,
                    active_limit_reached).await;
            },
            Some(discovery_event)=discovery_rx.recv(),if !stopping=>match discovery_event{
                DiscoveryEvent::Discovered{device}|DiscoveryEvent::Updated{device}=>{
                    let item=device_json_from_discovered(&device);
                    let fingerprint=item["fingerprint"].as_str().unwrap_or_default().to_string();
                    if last_devices.get(&fingerprint)!=Some(&item){last_devices.insert(fingerprint,item.clone());
                        emit(&output_tx,event("device",json!({"id":Value::Null,"device":item}))).await;}
                }
                DiscoveryEvent::MulticastFailed=>emit(&output_tx,event("warning",json!({"id":Value::Null,"code":"multicast_unavailable",
                    "message":"multicast discovery failed; staged scan is still available"}))).await,
            },
            Some(joined)=discovery_tasks.join_next(),if !discovery_tasks.is_empty()=>{
                if let Err(err)=joined{warn!("discovery task failed: {err}");}
            },
            Some(joined)=tasks.join_next(),if !tasks.is_empty()=>match joined{
                Ok(TaskEvent::Send(outcome))=>{
                    sends.remove(&outcome.transfer_id);
                    emit(&output_tx,finished_event(outcome)).await;
                }
                Ok(TaskEvent::ReceivedFile{session_id,file_id,result})=>{
                    if let Some(receive)=receives.get_mut(&session_id){
                        receive.active_files.remove(&file_id);
                        let file_name=receive.selected.get(&file_id).map(|file|file.file_name.clone()).unwrap_or_default();
                        let value=match result{
                            Ok((path,bytes))=>{
                                receive.transferred_bytes=receive.transferred_bytes.saturating_add(bytes);
                                json!({"fileId":file_id,"fileName":file_name,"state":"completed","bytes":bytes,"path":path})
                            }
                            Err(message)=>{
                                let cancelled=receive.cancellation.is_cancelled();
                                json!({"fileId":file_id,"fileName":file_name,"state":if cancelled{"cancelled"}else{"failed"},
                                    "error":{"code":if cancelled{"cancelled"}else{"receive_failed"},"message":message}})
                            }
                        };
                        emit(&output_tx,event("file_completed",json!({"id":receive.command_id,"sessionId":session_id,
                            "transferId":receive.transfer_id,"file":value}))).await;
                        receive.outcomes.insert(file_id,value);
                    }
                    let _=finalize_receive_if_ready(&session_id,&mut receives,&output_tx).await;
                }
                Err(err)=>warn!("transfer task failed unexpectedly: {err}"),
            },
            Some(value)=output_rx.recv()=>{
                println!("{value}");
                io::stdout().flush()?;
            },
            _=tick.tick()=>{
                let now=tokio::time::Instant::now();
                let expired:Vec<String>=pending.iter().filter(|(_,request)|receive_request_expired(request.deadline,now)).map(|(session,_)|session.clone()).collect();
                for session_id in expired{
                    if let Some(request)=pending.remove(&session_id){let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);
                        emit(&output_tx,event("incoming_expired",json!({"id":Value::Null,"sessionId":session_id,"transferId":request.transfer_id,
                            "confirmTimeoutSeconds":RECEIVE_CONFIRM_TIMEOUT.as_secs()}))).await;}
                }
                if stopping&&graceful_shutdown_expired(forced,shutdown_deadline,now){
                    forced=true;
                    emit(&output_tx,event("shutdown_timeout",json!({"id":Value::Null,"action":"cancelling_active_transfers"}))).await;
                    for send in sends.values(){send.cancellation.cancel();}
                    for(session,receive)in receives.iter_mut(){receive.cancel_requested=true;receive.cancellation.cancel();let _=server.cancel_v2_session(session).await;}
                    force_deadline=Some(now+FORCED_SHUTDOWN_GRACE);
                }
                let cancelled_without_files:Vec<String>=receives.iter()
                    .filter(|(_,receive)|receive.cancel_requested&&receive.active_files.is_empty())
                    .map(|(session,_)|session.clone()).collect();
                for session in cancelled_without_files{let _=finalize_receive_if_ready(&session,&mut receives,&output_tx).await;}
                if stopping&&forced&&force_deadline.is_some_and(|deadline|now>=deadline)&&!tasks.is_empty(){
                    tasks.abort_all();
                    while let Some(joined)=tasks.join_next().await{if let Err(err)=joined{if !err.is_cancelled(){warn!("task failed during forced shutdown: {err}");}}}
                    for(transfer_id,send)in sends.drain(){emit(&output_tx,event("transfer_finished",json!({"id":send.command_id,
                        "transferId":transfer_id,"state":"cancelled","files":[],"error":null}))).await;}
                    for(session,receive)in receives.drain(){emit(&output_tx,event("transfer_finished",json!({"id":receive.command_id,
                        "sessionId":session,"transferId":receive.transfer_id,"state":"cancelled","files":[],"error":null}))).await;}
                }
            },
            _=terminate.recv(),if !stopping=>{
                stopping=true;forced=true;shutdown_deadline=Some(tokio::time::Instant::now());force_deadline=Some(tokio::time::Instant::now()+FORCED_SHUTDOWN_GRACE);
                if let Some(stop)=discovery_stop_tx.take(){let _=stop.send(());}
                for(_,request)in pending.drain(){let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);}
                for send in sends.values(){send.cancellation.cancel();}
                for(session,receive)in receives.iter_mut(){receive.cancel_requested=true;receive.cancellation.cancel();let _=server.cancel_v2_session(session).await;}
            }
            _=interrupt.recv(),if !stopping=>{
                stopping=true;forced=true;shutdown_deadline=Some(tokio::time::Instant::now());force_deadline=Some(tokio::time::Instant::now()+FORCED_SHUTDOWN_GRACE);
                if let Some(stop)=discovery_stop_tx.take(){let _=stop.send(());}
                for(_,request)in pending.drain(){let _=request.decision_tx.send(PrepareUploadDecisionV2::Decline);}
                for send in sends.values(){send.cancellation.cancel();}
                for(session,receive)in receives.iter_mut(){receive.cancel_requested=true;receive.cancellation.cancel();let _=server.cancel_v2_session(session).await;}
            },
        }
    }
    if let Some(stop) = discovery_stop_tx.take() {
        let _ = stop.send(());
    }
    emit(&output_tx, event("stopped", json!({"state":"stopped"}))).await;
    drop(output_tx);
    while let Some(value) = output_rx.recv().await {
        println!("{value}");
    }
    io::stdout().flush()?;
    Ok(())
}

#[tokio::main]
async fn main() {
    if let Err(err) = main_loop().await {
        eprintln!("LocalSend backend failure: {err:#}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn bounded_reader_recovers_after_oversized_line() {
        let input = format!(
            "{}\n{{\"cmd\":\"devices\",\"id\":\"x\"}}\n",
            "x".repeat(MAX_JSONL_LINE + 2)
        );
        let mut reader = tokio::io::BufReader::new(input.as_bytes());
        assert!(matches!(
            read_bounded_line(&mut reader).await.unwrap(),
            ReadLine::TooLong
        ));
        assert!(matches!(
            read_bounded_line(&mut reader).await.unwrap(),
            ReadLine::Line(_)
        ));
    }
    #[test]
    fn every_event_has_v1_envelope() {
        let value = event("test", json!({"id":"cmd-1"}));
        assert_eq!(value["v"], 1);
        assert_eq!(value["event"], "test");
        assert_eq!(value["id"], "cmd-1");
    }

    #[test]
    fn command_ids_are_unique_for_the_process_lifetime() {
        let mut ids = HashSet::new();
        assert_eq!(remember_command_id("one", &mut ids), Ok(()));
        assert_eq!(
            remember_command_id("one", &mut ids),
            Err("duplicate_command_id")
        );
        assert_eq!(ids.len(), 1);
    }

    #[test]
    fn cancelled_send_reports_completed_and_unstarted_files() {
        let sources = vec![
            (PathBuf::from("a.txt"), "a.txt".into(), 3, "file-a".into()),
            (PathBuf::from("b.txt"), "b.txt".into(), 4, "file-b".into()),
        ];
        let outcome = cancelled_send(
            "transfer-1",
            "command-1",
            &sources,
            vec![json!({"fileId":"file-a","state":"completed","bytes":3})],
        );
        assert_eq!(outcome.state, "cancelled");
        assert_eq!(outcome.files.len(), 2);
        assert_eq!(outcome.files[0]["state"], "completed");
        assert_eq!(outcome.files[1]["state"], "cancelled");
    }

    #[cfg(unix)]
    #[test]
    fn identity_file_permissions_are_private_and_symlinks_rejected() {
        use std::os::unix::fs::{MetadataExt, PermissionsExt, symlink};
        let dir = std::env::temp_dir().join(format!("vdx-identity-test-{}", Uuid::new_v4()));
        std::fs::create_dir(&dir).unwrap();
        let identity = dir.join("identity.pem");
        std::fs::write(&identity, "not parsed by this permission test").unwrap();
        std::fs::set_permissions(&identity, std::fs::Permissions::from_mode(0o644)).unwrap();
        ensure_private_identity_file(&identity).unwrap();
        assert_eq!(std::fs::metadata(&identity).unwrap().mode() & 0o777, 0o600);
        let link = dir.join("identity-link.pem");
        symlink(&identity, &link).unwrap();
        assert!(ensure_private_identity_file(&link).is_err());
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn confirmation_and_shutdown_deadlines_are_deterministic() {
        let now = tokio::time::Instant::now();
        assert!(!receive_request_expired(now + Duration::from_secs(1), now));
        assert!(receive_request_expired(now, now));
        assert!(!graceful_shutdown_expired(
            false,
            Some(now + Duration::from_secs(1)),
            now
        ));
        assert!(graceful_shutdown_expired(false, Some(now), now));
        assert!(!graceful_shutdown_expired(true, Some(now), now));
    }

    #[tokio::test]
    async fn cancelled_receive_has_one_terminal_event_and_cancel_is_idempotent() {
        let cancellation = CancellationToken::new();
        cancellation.cancel();
        cancellation.cancel();
        assert!(cancellation.is_cancelled());

        let mut receives = HashMap::from([(
            "session-1".to_string(),
            ReceiveSession {
                transfer_id: "transfer-1".into(),
                command_id: "accept-1".into(),
                alias: "phone".into(),
                fingerprint: "fingerprint".into(),
                selected: HashMap::new(),
                active_files: HashSet::new(),
                outcomes: HashMap::new(),
                cancellation,
                file_semaphore: Arc::new(tokio::sync::Semaphore::new(2)),
                progress_bytes: Arc::new(std::sync::atomic::AtomicU64::new(0)),
                total_bytes: 0,
                transferred_bytes: 0,
                remote_ended: None,
                cancel_requested: true,
            },
        )]);
        let (tx, mut rx) = mpsc::channel(4);
        assert!(finalize_receive_if_ready("session-1", &mut receives, &tx).await);
        assert!(!finalize_receive_if_ready("session-1", &mut receives, &tx).await);
        let terminal = rx.recv().await.unwrap();
        assert_eq!(terminal["event"], "transfer_finished");
        assert_eq!(terminal["state"], "cancelled");
        assert!(rx.try_recv().is_err());
    }
}
