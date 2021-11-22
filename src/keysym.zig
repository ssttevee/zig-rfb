const KeySym = @This();

value: u32,

pub const backspace = fromInt(0xFF08);
pub const tab = fromInt(0xFF09);
pub const enter = fromInt(0xFF0D);
pub const escape = fromInt(0xFF1B);
pub const insert = fromInt(0xFF63);
pub const delete = fromInt(0xFFFF);
pub const home = fromInt(0xFF50);
pub const end = fromInt(0xFF57);
pub const page_up = fromInt(0xFF55);
pub const page_down = fromInt(0xFF56);
pub const left = fromInt(0xFF51);
pub const up = fromInt(0xFF52);
pub const right = fromInt(0xFF53);
pub const down = fromInt(0xFF54);
pub const f1 = fromInt(0xFFBE);
pub const f2 = fromInt(0xFFBF);
pub const f3 = fromInt(0xFFC0);
pub const f4 = fromInt(0xFFC1);
pub const f5 = fromInt(0xFFC2);
pub const f6 = fromInt(0xFFC3);
pub const f7 = fromInt(0xFFC4);
pub const f8 = fromInt(0xFFC5);
pub const f9 = fromInt(0xFFC6);
pub const f10 = fromInt(0xFFC7);
pub const f11 = fromInt(0xFFC8);
pub const f12 = fromInt(0xFFC9);
pub const shift_left = fromInt(0xFFE1);
pub const shift_right = fromInt(0xFFE2);
pub const control_left = fromInt(0xFFE3);
pub const control_right = fromInt(0xFFE4);
pub const meta_left = fromInt(0xFFE7);
pub const meta_right = fromInt(0xFFE8);
pub const alt_left = fromInt(0xFFE9);
pub const alt_right = fromInt(0xFFEA);

pub fn fromInt(value: u32) KeySym {
    return .{ .value = value };
}
