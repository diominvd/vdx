use anyhow::{Context, Result};
use localsend::model::transfer::FileDto;
use sha2::{Digest, Sha256};
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

#[cfg(not(target_os = "linux"))]
compile_error!("the VDX LocalSend helper requires Linux directory-fd semantics");

const TEMP_PREFIX: &str = ".vdx-localsend-";
const TEMP_SUFFIX: &str = ".part";
const IO_BUFFER_SIZE: usize = 256 * 1024;

#[derive(Clone)]
pub struct DownloadRoot {
    canonical: PathBuf,
    handle: Arc<std::fs::File>,
    io_path: PathBuf,
}

impl DownloadRoot {
    pub fn display_path(&self) -> &Path {
        &self.canonical
    }

    fn io_path(&self) -> &Path {
        let _keep_handle_open = &self.handle;
        &self.io_path
    }
}

pub struct TempFileGuard {
    path: PathBuf,
    keep: bool,
}

impl TempFileGuard {
    fn new(path: PathBuf) -> Self {
        Self { path, keep: false }
    }

    fn keep(mut self) -> PathBuf {
        self.keep = true;
        self.path.clone()
    }
}

impl Drop for TempFileGuard {
    fn drop(&mut self) {
        if !self.keep {
            // Drop also runs when a Tokio task is aborted, where async cleanup cannot run.
            let _ = std::fs::remove_file(&self.path);
        }
    }
}

pub fn prepare_download_dir(path: &Path) -> Result<DownloadRoot> {
    std::fs::create_dir_all(path)
        .with_context(|| format!("create download directory {}", path.display()))?;
    let root = std::fs::canonicalize(path)
        .with_context(|| format!("resolve download directory {}", path.display()))?;
    if !std::fs::metadata(&root)?.is_dir() {
        anyhow::bail!("download path is not a directory");
    }
    let handle = Arc::new(std::fs::File::open(&root).context("open resolved download directory")?);
    let io_path = {
        use std::os::fd::AsRawFd;
        PathBuf::from(format!("/proc/self/fd/{}", handle.as_raw_fd()))
    };
    Ok(DownloadRoot {
        canonical: root,
        handle,
        io_path,
    })
}

pub fn cleanup_stale_parts(root: &Path) -> io::Result<usize> {
    let mut removed = 0;
    for entry in std::fs::read_dir(root)? {
        let entry = entry?;
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        let Some(id) = name
            .strip_prefix(TEMP_PREFIX)
            .and_then(|name| name.strip_suffix(TEMP_SUFFIX))
        else {
            continue;
        };
        if uuid::Uuid::parse_str(id).is_err() {
            continue;
        }
        let metadata = std::fs::symlink_metadata(entry.path())?;
        if metadata.file_type().is_file() {
            std::fs::remove_file(entry.path())?;
            removed += 1;
        }
    }
    Ok(removed)
}

pub fn safe_basename(name: &str) -> Result<&str, String> {
    if name.is_empty()
        || name == "."
        || name == ".."
        || name.len() > 255
        || name.contains('/')
        || name.contains('\\')
        || name.chars().any(char::is_control)
    {
        return Err("unsafe filename; expected a single basename of at most 255 bytes".to_string());
    }
    Ok(name)
}

fn temp_path(root: &DownloadRoot) -> PathBuf {
    root.io_path().join(format!(
        "{TEMP_PREFIX}{}{TEMP_SUFFIX}",
        uuid::Uuid::new_v4()
    ))
}

pub async fn hash_file(path: &Path, cancel: &CancellationToken) -> Result<(u64, String)> {
    let mut file = tokio::fs::File::open(path)
        .await
        .with_context(|| format!("open source file {}", path.display()))?;
    let mut buffer = vec![0; IO_BUFFER_SIZE];
    let mut size = 0_u64;
    let mut hash = Sha256::new();
    loop {
        let count = tokio::select! {
            _ = cancel.cancelled() => anyhow::bail!("transfer cancelled"),
            result = file.read(&mut buffer) => result.context("read source file")?,
        };
        if count == 0 {
            break;
        }
        size = size.saturating_add(count as u64);
        hash.update(&buffer[..count]);
    }
    Ok((size, hex(&hash.finalize())))
}

pub async fn receive_stream(
    root: &DownloadRoot,
    file: &FileDto,
    receiver: &mut mpsc::Receiver<bytes::Bytes>,
    cancel: &CancellationToken,
    mut progress: impl FnMut(u64),
) -> Result<(PathBuf, u64), String> {
    let basename = safe_basename(&file.file_name)?;
    let temp = temp_path(root);
    #[cfg(unix)]
    let std_target = {
        use std::os::unix::fs::OpenOptionsExt;
        std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temp)
            .map_err(|err| format!("create private temporary file: {err}"))?
    };
    #[cfg(not(unix))]
    let std_target = tokio::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temp)
        .await
        .map_err(|err| format!("create private temporary file: {err}"))?;
    #[cfg(unix)]
    let mut target = tokio::fs::File::from_std(std_target);
    #[cfg(not(unix))]
    let mut target = std_target;
    let guard = TempFileGuard::new(temp.clone());
    let mut hasher = Sha256::new();
    let mut received = 0_u64;
    loop {
        let chunk = tokio::select! {
            _ = cancel.cancelled() => return Err("transfer cancelled".to_string()),
            chunk = receiver.recv() => chunk,
        };
        let Some(chunk) = chunk else { break };
        received = received.saturating_add(chunk.len() as u64);
        if received > file.size {
            return Err(format!(
                "received more bytes than offered size {}",
                file.size
            ));
        }
        target
            .write_all(&chunk)
            .await
            .map_err(|err| format!("write received data: {err}"))?;
        hasher.update(&chunk);
        progress(received);
    }
    if received != file.size {
        return Err(format!(
            "truncated transfer: received {received} of {} bytes",
            file.size
        ));
    }
    if let Some(expected) = &file.sha256 {
        let actual = hex(&hasher.finalize());
        if !actual.eq_ignore_ascii_case(expected) {
            return Err("SHA-256 checksum mismatch".to_string());
        }
    }
    target
        .flush()
        .await
        .map_err(|err| format!("flush received data: {err}"))?;
    target
        .sync_all()
        .await
        .map_err(|err| format!("sync received data: {err}"))?;
    drop(target);

    let committed = commit_no_replace(&temp, root, basename).await?;
    drop(guard.keep());
    Ok((committed, received))
}

async fn commit_no_replace(
    temp: &Path,
    root: &DownloadRoot,
    name: &str,
) -> Result<PathBuf, String> {
    let path = Path::new(name);
    let stem = path.file_stem().and_then(|v| v.to_str()).unwrap_or("file");
    let extension = path
        .extension()
        .and_then(|v| v.to_str())
        .map(|v| format!(".{v}"))
        .unwrap_or_default();
    for index in 0..10_000_u32 {
        let candidate_name = if index == 0 {
            name.to_string()
        } else {
            conflict_name(name, stem, &extension, index)
        };
        let candidate = root.canonical.join(&candidate_name);
        let candidate_io = root.io_path().join(candidate_name);
        let temp_for_link = temp.to_path_buf();
        let candidate_for_link = candidate_io;
        match tokio::task::spawn_blocking(move || {
            std::fs::hard_link(temp_for_link, candidate_for_link)
        })
        .await
        {
            Ok(Ok(())) => {
                tokio::fs::remove_file(temp)
                    .await
                    .map_err(|err| format!("remove completed temporary file: {err}"))?;
                return Ok(candidate);
            }
            Ok(Err(err)) if err.kind() == io::ErrorKind::AlreadyExists => continue,
            Ok(Err(err)) => return Err(format!("commit received file without overwrite: {err}")),
            Err(err) => return Err(format!("finalize received file task: {err}")),
        }
    }
    Err("too many conflicting filenames".to_string())
}

fn conflict_name(name: &str, stem: &str, extension: &str, index: u32) -> String {
    let suffix = format!(" ({index})");
    let stem_limit = 255usize.saturating_sub(extension.len() + suffix.len());
    if stem_limit > 0 {
        format!("{}{suffix}{extension}", truncate_utf8(stem, stem_limit))
    } else {
        let name_limit = 255usize.saturating_sub(suffix.len());
        format!("{}{suffix}", truncate_utf8(name, name_limit))
    }
}

fn truncate_utf8(value: &str, max_bytes: usize) -> &str {
    let mut end = value.len().min(max_bytes);
    while !value.is_char_boundary(end) {
        end -= 1;
    }
    &value[..end]
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use localsend::model::transfer::FileMetadata;

    fn temp_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!("vdx-localsend-test-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir(&dir).unwrap();
        dir
    }

    fn dto(name: &str, bytes: &[u8]) -> FileDto {
        FileDto {
            id: "file-1".into(),
            file_name: name.into(),
            size: bytes.len() as u64,
            file_type: "application/octet-stream".into(),
            sha256: Some(hex(&Sha256::digest(bytes))),
            preview: None,
            metadata: Some(FileMetadata {
                modified: None,
                accessed: None,
            }),
        }
    }

    #[test]
    fn rejects_paths_control_characters_and_oversized_names() {
        for name in ["", ".", "..", "../escape", "a/b", "a\\b", "bad\nname"] {
            assert!(safe_basename(name).is_err(), "{name:?}");
        }
        assert!(safe_basename(&"x".repeat(256)).is_err());
        assert_eq!(safe_basename("photo.jpg"), Ok("photo.jpg"));
    }

    #[tokio::test]
    async fn commits_without_overwrite_and_resolves_duplicate_names() {
        let dir = temp_dir();
        let root = prepare_download_dir(&dir).unwrap();
        std::fs::write(dir.join("a.txt"), b"untouched").unwrap();
        for data in [b"first".as_slice(), b"second".as_slice()] {
            let (tx, mut rx) = mpsc::channel(2);
            tx.send(bytes::Bytes::copy_from_slice(data)).await.unwrap();
            drop(tx);
            let result = receive_stream(
                &root,
                &dto("a.txt", data),
                &mut rx,
                &CancellationToken::new(),
                |_| {},
            )
            .await
            .unwrap();
            assert_eq!(std::fs::read(result.0).unwrap(), data);
        }
        assert_eq!(std::fs::read(dir.join("a.txt")).unwrap(), b"untouched");
        assert_eq!(std::fs::read(dir.join("a (1).txt")).unwrap(), b"first");
        assert_eq!(std::fs::read(dir.join("a (2).txt")).unwrap(), b"second");
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn conflict_names_stay_within_filesystem_name_limit() {
        let stem = "é".repeat(123);
        let name = format!("{stem}.txt");
        assert!(name.len() <= 255);
        let renamed = conflict_name(&name, &stem, ".txt", 1);
        assert!(renamed.len() <= 255);
        assert!(renamed.is_char_boundary(renamed.len()));
    }

    #[tokio::test]
    async fn removes_part_on_hash_failure_and_cancel() {
        let dir = temp_dir();
        let root = prepare_download_dir(&dir).unwrap();
        let mut bad = dto("bad.bin", b"hello");
        bad.sha256 = Some("00".repeat(32));
        let (tx, mut rx) = mpsc::channel(2);
        tx.send(bytes::Bytes::from_static(b"hello")).await.unwrap();
        drop(tx);
        assert!(
            receive_stream(&root, &bad, &mut rx, &CancellationToken::new(), |_| {})
                .await
                .is_err()
        );
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);

        let (tx, mut rx) = mpsc::channel(2);
        let cancel = CancellationToken::new();
        cancel.cancel();
        assert!(
            receive_stream(
                &root,
                &dto("cancel.bin", b"hello"),
                &mut rx,
                &cancel,
                |_| {}
            )
            .await
            .is_err()
        );
        drop(tx);
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[tokio::test]
    async fn aborted_receive_removes_its_part_file() {
        let dir = temp_dir();
        let root = prepare_download_dir(&dir).unwrap();
        let (_tx, mut rx) = mpsc::channel(1);
        let cancel = CancellationToken::new();
        let task = tokio::spawn(async move {
            receive_stream(
                &root,
                &dto("waiting.bin", b"waiting"),
                &mut rx,
                &cancel,
                |_| {},
            )
            .await
        });
        for _ in 0..100 {
            if std::fs::read_dir(&dir).unwrap().next().is_some() {
                break;
            }
            tokio::task::yield_now().await;
        }
        assert!(std::fs::read_dir(&dir).unwrap().next().is_some());
        task.abort();
        assert!(task.await.unwrap_err().is_cancelled());
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(target_os = "linux")]
    #[tokio::test]
    async fn directory_rename_does_not_redirect_an_in_flight_receive() {
        use std::os::unix::fs::symlink;

        let configured = temp_dir();
        let root = prepare_download_dir(&configured).unwrap();
        let relocated = configured.with_extension("relocated");
        std::fs::rename(&configured, &relocated).unwrap();
        let attacker_dir = temp_dir();
        symlink(&attacker_dir, &configured).unwrap();
        let data = b"safe destination";
        let (tx, mut rx) = mpsc::channel(1);
        tx.send(bytes::Bytes::from_static(data)).await.unwrap();
        drop(tx);
        receive_stream(
            &root,
            &dto("payload.bin", data),
            &mut rx,
            &CancellationToken::new(),
            |_| {},
        )
        .await
        .unwrap();
        assert_eq!(std::fs::read(relocated.join("payload.bin")).unwrap(), data);
        assert!(!attacker_dir.join("payload.bin").exists());
        std::fs::remove_file(configured).unwrap();
        std::fs::remove_dir_all(relocated).unwrap();
        std::fs::remove_dir_all(attacker_dir).unwrap();
    }

    #[test]
    fn startup_cleanup_removes_only_generated_regular_parts() {
        let dir = temp_dir();
        let generated = dir.join(format!(
            "{TEMP_PREFIX}{}{TEMP_SUFFIX}",
            uuid::Uuid::new_v4()
        ));
        let unrelated = dir.join("notes.part");
        std::fs::write(&generated, b"partial").unwrap();
        std::fs::write(&unrelated, b"keep").unwrap();
        assert_eq!(cleanup_stale_parts(&dir).unwrap(), 1);
        assert!(!generated.exists());
        assert!(unrelated.exists());
        std::fs::remove_dir_all(dir).unwrap();
    }
}
