//! Map egui keys to PC AT scancodes used by RDP FastPath / VNC keysym helper.

use egui::Key;

/// Returns (scancode, is_extended_hint).
pub fn egui_key_to_scancode(key: Key) -> Option<(i32, bool)> {
    Some(match key {
        Key::Escape => (0x01, false),
        Key::Tab => (0x0F, false),
        Key::Backspace => (0x0E, false),
        Key::Enter => (0x1C, false),
        Key::Space => (0x39, false),

        Key::Num0 => (0x0B, false),
        Key::Num1 => (0x02, false),
        Key::Num2 => (0x03, false),
        Key::Num3 => (0x04, false),
        Key::Num4 => (0x05, false),
        Key::Num5 => (0x06, false),
        Key::Num6 => (0x07, false),
        Key::Num7 => (0x08, false),
        Key::Num8 => (0x09, false),
        Key::Num9 => (0x0A, false),

        Key::A => (0x1E, false),
        Key::B => (0x30, false),
        Key::C => (0x2E, false),
        Key::D => (0x20, false),
        Key::E => (0x12, false),
        Key::F => (0x21, false),
        Key::G => (0x22, false),
        Key::H => (0x23, false),
        Key::I => (0x17, false),
        Key::J => (0x24, false),
        Key::K => (0x25, false),
        Key::L => (0x26, false),
        Key::M => (0x32, false),
        Key::N => (0x31, false),
        Key::O => (0x18, false),
        Key::P => (0x19, false),
        Key::Q => (0x10, false),
        Key::R => (0x13, false),
        Key::S => (0x1F, false),
        Key::T => (0x14, false),
        Key::U => (0x16, false),
        Key::V => (0x2F, false),
        Key::W => (0x11, false),
        Key::X => (0x2D, false),
        Key::Y => (0x15, false),
        Key::Z => (0x2C, false),

        Key::F1 => (0x3B, false),
        Key::F2 => (0x3C, false),
        Key::F3 => (0x3D, false),
        Key::F4 => (0x3E, false),
        Key::F5 => (0x3F, false),
        Key::F6 => (0x40, false),
        Key::F7 => (0x41, false),
        Key::F8 => (0x42, false),
        Key::F9 => (0x43, false),
        Key::F10 => (0x44, false),
        Key::F11 => (0x57, false),
        Key::F12 => (0x58, false),

        Key::ArrowLeft => (0x4B, true),
        Key::ArrowUp => (0x48, true),
        Key::ArrowRight => (0x4D, true),
        Key::ArrowDown => (0x50, true),
        Key::Home => (0x47, true),
        Key::End => (0x4F, true),
        Key::PageUp => (0x49, true),
        Key::PageDown => (0x51, true),
        Key::Insert => (0x52, true),
        Key::Delete => (0x53, true),

        Key::Minus => (0x0C, false),
        Key::Equals => (0x0D, false),
        Key::OpenBracket => (0x1A, false),
        Key::CloseBracket => (0x1B, false),
        Key::Backslash => (0x2B, false),
        Key::Semicolon => (0x27, false),
        Key::Quote => (0x28, false),
        Key::Backtick => (0x29, false),
        Key::Comma => (0x33, false),
        Key::Period => (0x34, false),
        Key::Slash => (0x35, false),

        // Modifier keys are tracked via egui::Modifiers, not Key variants in egui 0.31.
        _ => return None,
    })
}

pub fn is_extended_scancode(scancode: i32) -> bool {
    matches!(
        scancode,
        0x4B | 0x48 | 0x4D | 0x50 | 0x47 | 0x4F | 0x49 | 0x51 | 0x52 | 0x53
    )
}
