package types;

import ttf  "vendor:stb/truetype";

Font :: struct #packed {
    bytes:        []byte,
    color:        [4]u32,
    cdata:        []ttf.bakedchar, // Stores metrics for ASCII 32-126
    font_bitmap:  []u8,
    texture_id: u32,
    width_pixels, height_pixels: u8,
}

FontError :: enum u8 {
    None = 0,
    InvalidFont,
    InvalidBitmap
}