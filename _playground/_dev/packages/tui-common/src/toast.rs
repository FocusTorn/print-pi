// Toast notification component

use std::time::SystemTime;

#[derive(Debug, Clone)]
pub enum ToastType {
    Success,
    Error,
    Info,
}

#[derive(Debug, Clone)]
pub struct Toast {
    pub message: String,
    pub toast_type: ToastType,
    pub shown_at: SystemTime,
}

impl Toast {
    pub fn new(message: impl Into<String>, toast_type: ToastType) -> Self {
        Toast {
            message: message.into(),
            toast_type,
            shown_at: SystemTime::now(),
        }
    }
}

