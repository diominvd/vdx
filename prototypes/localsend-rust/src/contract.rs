use serde::Deserialize;

pub const VERSION: u8 = 1;
pub const MAX_FILES_PER_TRANSFER: usize = 100;

#[derive(Debug, Deserialize)]
#[serde(tag = "cmd", deny_unknown_fields)]
pub enum Command {
    #[serde(rename = "discover")]
    Discover { id: String },
    #[serde(rename = "devices")]
    Devices { id: String },
    #[serde(rename = "send")]
    Send {
        id: String,
        fingerprint: String,
        paths: Vec<String>,
    },
    #[serde(rename = "accept")]
    Accept {
        id: String,
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(rename = "fileIds")]
        file_ids: Vec<String>,
    },
    #[serde(rename = "reject")]
    Reject {
        id: String,
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    #[serde(rename = "cancel")]
    Cancel {
        id: String,
        #[serde(rename = "transferId")]
        transfer_id: String,
    },
    #[serde(rename = "status")]
    Status { id: String },
    #[serde(rename = "shutdown")]
    Shutdown {
        id: String,
        #[serde(default, rename = "force")]
        force: bool,
        #[serde(default, rename = "timeoutMs")]
        timeout_ms: Option<u64>,
    },
}

impl Command {
    pub fn id(&self) -> &str {
        match self {
            Self::Discover { id }
            | Self::Devices { id }
            | Self::Send { id, .. }
            | Self::Accept { id, .. }
            | Self::Reject { id, .. }
            | Self::Cancel { id, .. }
            | Self::Status { id }
            | Self::Shutdown { id, .. } => id,
        }
    }

    pub fn validate(&self) -> Result<(), &'static str> {
        if self.id().is_empty() || self.id().len() > 128 {
            return Err("id must contain 1 to 128 bytes");
        }
        match self {
            Self::Send {
                fingerprint, paths, ..
            } => {
                if fingerprint.is_empty() || fingerprint.len() > 128 {
                    return Err("fingerprint must contain 1 to 128 bytes");
                }
                if paths.is_empty() || paths.len() > MAX_FILES_PER_TRANSFER {
                    return Err("paths must contain 1 to 100 entries");
                }
                if paths
                    .iter()
                    .any(|path| path.is_empty() || path.len() > 16 * 1024)
                {
                    return Err("each path must contain 1 to 16384 bytes");
                }
            }
            Self::Accept {
                session_id,
                file_ids,
                ..
            } => {
                if session_id.is_empty() || session_id.len() > 128 {
                    return Err("sessionId must contain 1 to 128 bytes");
                }
                if file_ids.is_empty() || file_ids.len() > MAX_FILES_PER_TRANSFER {
                    return Err("fileIds must contain 1 to 100 entries");
                }
                if file_ids
                    .iter()
                    .any(|file_id| file_id.is_empty() || file_id.len() > 128)
                {
                    return Err("each fileId must contain 1 to 128 bytes");
                }
            }
            Self::Reject { session_id, .. } if session_id.is_empty() || session_id.len() > 128 => {
                return Err("sessionId must contain 1 to 128 bytes");
            }
            Self::Cancel { transfer_id, .. }
                if transfer_id.is_empty() || transfer_id.len() > 128 =>
            {
                return Err("transferId must contain 1 to 128 bytes");
            }
            Self::Shutdown {
                timeout_ms: Some(ms),
                ..
            } if *ms > 120_000 => {
                return Err("timeoutMs must not exceed 120000");
            }
            _ => {}
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_v1_send_and_accept_commands() {
        let send: Command = serde_json::from_str(
            r#"{"cmd":"send","id":"s1","fingerprint":"abc","paths":["/tmp/a"]}"#,
        )
        .unwrap();
        assert_eq!(send.id(), "s1");
        assert!(send.validate().is_ok());

        let accept: Command = serde_json::from_str(
            r#"{"cmd":"accept","id":"a1","sessionId":"peer-1","fileIds":["f1","f2"]}"#,
        )
        .unwrap();
        assert!(accept.validate().is_ok());
    }

    #[test]
    fn rejects_unknown_fields_and_missing_ids() {
        assert!(
            serde_json::from_str::<Command>(r#"{"cmd":"devices","id":"x","extra":true}"#).is_err()
        );
        assert!(serde_json::from_str::<Command>(r#"{"cmd":"devices"}"#).is_err());
        assert!(serde_json::from_str::<Command>(r#"{"cmd":"wat","id":"x"}"#).is_err());
    }

    #[test]
    fn bounds_send_and_shutdown() {
        let send: Command = serde_json::from_value(serde_json::json!({
            "cmd":"send", "id":"x", "fingerprint":"abc", "paths":[]
        }))
        .unwrap();
        assert!(send.validate().is_err());
        let shutdown: Command = serde_json::from_value(serde_json::json!({
            "cmd":"shutdown", "id":"x", "timeoutMs":120001
        }))
        .unwrap();
        assert!(shutdown.validate().is_err());
    }
}
