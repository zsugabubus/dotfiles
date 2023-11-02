use std::os::raw::*;

#[repr(C)]
pub struct Highlight {
    start_col: c_int,
    end_col: c_int,
    color: u32,
}

#[no_mangle]
pub unsafe extern "C" fn nvim_buf_get_color_matches(
    buffer: c_int,
    row: c_int,
    out: *mut Highlight,
    out_len: usize,
) -> c_int {
    use std::ops::ControlFlow;

    let server = nvim::Server::new();
    let Some(buffer) = server.get_buffer(nvim::BufferId(buffer)) else {
        return 0;
    };
    let line = buffer.get_line(nvim::Row(row));

    let out = std::slice::from_raw_parts_mut(out, out_len);

    let mut index: usize = 0;

    crate::search::search(line, |m| {
        if let Some(item) = out.get_mut(index) {
            item.start_col = m.first() as c_int;
            item.end_col = m.last() as c_int;
            item.color = m.color();
            index += 1;
            ControlFlow::Continue(())
        } else {
            ControlFlow::Break(())
        }
    });

    index as c_int
}

#[no_mangle]
pub extern "C" fn nvim_is_bright_background_color(color: u32) -> c_int {
    use apca::{lightness, Background, Lightness};
    use palette::{rgb::channels::Rgba, Srgb};
    let rgb = Srgb::from_u32::<Rgba>((color << 8) | 0xff).into_format::<f32>();
    match lightness(Background(rgb.into_components())) {
        Lightness::Dark => 0,
        Lightness::Light => 1,
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn nvim_is_bright_background_color() {
        use super::*;

        assert_eq!(nvim_is_bright_background_color(0x000000), 0);
        assert_eq!(nvim_is_bright_background_color(0xffffff), 1);
        assert_eq!(nvim_is_bright_background_color(0xff0000), 0);
        assert_eq!(nvim_is_bright_background_color(0x808080), 0);
        // Different Text/Background lightness.
        assert_eq!(nvim_is_bright_background_color(0xa3a3a3), 0);
    }
}
