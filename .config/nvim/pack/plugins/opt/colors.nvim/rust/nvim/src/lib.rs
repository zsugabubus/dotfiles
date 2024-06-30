use std::os::raw::*;

#[derive(Clone, Copy)]
#[repr(transparent)]
pub struct Row(pub c_int);

#[derive(Clone, Copy)]
#[repr(transparent)]
pub struct BufferId(pub c_int);

#[derive(Clone, Copy)]
#[repr(transparent)]
pub struct Buffer(&'static c_void);

impl Buffer {
    /// # Safety
    ///
    /// - Buffer pointer is valid.
    ///
    /// - Returned slice is dropped before `ml_get_buf` would invalidate the internal pointer.
    ///
    /// Refer to Neovim internals.
    pub unsafe fn get_line_with_nul(self, row: Row) -> &'static [u8] {
        extern "C" {
            fn ml_get_buf(_: *const c_void, _: i32) -> *const u8;
            fn ml_get_buf_len(_: *const c_void, _: i32) -> c_int;
        }

        let ptr = ml_get_buf(self.0, row.0);
        let len: usize = ml_get_buf_len(self.0, row.0).try_into().unwrap();
        let len_with_nul = len + 1;
        std::slice::from_raw_parts(ptr, len_with_nul)
    }
}

pub fn get_buffer(handle: BufferId) -> Option<Buffer> {
    extern "C" {
        fn buflist_findnr(_: c_int) -> *const c_void;
    }

    unsafe { buflist_findnr(handle.0).as_ref() }.map(Buffer)
}
